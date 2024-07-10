#!/bin/gst -f
" Copyright (c) 2024 Matheus Garcia.  All rights reserved.

  Redistribution and use in source and binary forms, with or without
  modification, are permitted provided that the following conditions are met:

  1. Redistributions of source code must retain the above copyright notice,
     this list of conditions and the following disclaimer. 

  2. Redistributions in binary form must reproduce the above copyright notice,
     this list of conditions and the following disclaimer in the documentation
     and/or other materials provided with the distribution. 

  3. Neither the name of the author nor the names of its contributors may be
     used to endorse or promote products derived from this software without
     specific prior written permission. 

  THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
  ""AS IS"" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
  LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS
  FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE
  COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT,
  INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING,
  BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS
  OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED
  AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
  OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT
  OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH
  DAMAGE. "

(Smalltalk getenv: 'USER') = 'root' ifFalse: [
    ('Must be root.', (Character nl asString))
    displayOn: stderr.
    ObjectMemory quit: -1.
].
path := Smalltalk getenv: 'PATH'.
[ | stream ret |
    stream := ReadStream on: path.
    ret := false.
    [ stream atEnd not and: [ ret not. ]. ] whileTrue: [
	ret := (File path: ((stream upTo: $:), '/rpm2cpio')) exists.
    ].
    ret ifFalse: [
	('rpm2cpio isn''t installed. ',
	 'Install rpm2cpio and try again.',
	 (Character nl asString)) displayOn: stderr.
	ObjectMemory quit: -1.
    ].
] value.

'Preparing to download...' displayNl.
PackageLoader fileInPackage: 'NetClients'.
host := 'http://mirrors.edge.kernel.org/fedora-buffet/fedora/linux/development/rawhide/Everything/', (Smalltalk getenv: 'MACHTYPE'), '/os/Packages/k/'.
kernel := [ ReadStream on: (((NetClients.URL fromString: host)
			     contents =~ 'kernel-core-.*') match). ]
	  on: Exception do: [ :e | ('No internet connection, ',
				    'or unsupported architecture. ',
				    'Aborting...', (Character nl asString))
				   displayOn: stderr.
				   ObjectMemory quit: -1. ].
kernel next: 12.
kernel := kernel upToEnd copyReplacingRegex: '\.rpm.*' with: ''.
home := Smalltalk getenv: 'HOME'.

(packages := Bag new) add: (File path: (home, '/kernel-core-', kernel, '.rpm')).
packages add: (File path: (home, '/kernel-modules-', kernel, '.rpm')).
packages add: (File path: (home, '/kernel-modules-extra-', kernel, '.rpm')).
packages add: (File path: (home, '/kernel-modules-internal-', kernel, '.rpm')).
packages do: [ :pkg | | name fd url |
    name := ReadStream on: (pkg name).
    [ name skipTo: $/. ] whileTrue: [
	name := ReadStream on: (name upToEnd).
    ].
    ('Downloading ', (name := name contents), '...') displayNl.
    (fd := pkg open: 'w') nextPutAll: ((url := NetClients.URL fromString:
					(host, name)) contents).
    fd close.
    'Verifying integrity...' displayNl.
    ((fd := pkg open: 'r') contents hash) = (url contents hash) ifFalse: [
	('Unmatched hash. Aborting...', (Character nl asString))
	displayOn: stderr.
	ObjectMemory quit: -1.
    ].
    fd close.
].
[ | pipe exc run pkg rand |
    pipe := FileStream popen: ('rpm2cpio ', home, '/',
			       (pkg := 'kernel-core-', kernel,
				'.rpm')) dir: 'r'.
    rand := Random new.
    exc := ''.
    [ exc size < 8. ] whileTrue: [ | char |
	[
	    (char := Character value:
	     (rand next asFraction numerator
	      bitClear: (16rFF bitInvert))) isLetter or: [
		char isDigit. ].
	] whileFalse.
	exc := exc, (char asString).
    ].
    (exc := (File path: (home, '/', exc)) open: 'w')
    nextPutAll: './usr/*'.
    exc := exc reset.
    run := FileStream popen: ('cpio -D / -u -i -d -m -E ',
			      exc) dir: 'w'.
    ('Installing ', pkg, '...') displayNl.
    run nextPutAll: (pipe contents)
    pipe close.
    run close.
    pipe := FileStream popen: ('rpm2cpio ', home, '/', pkg) dir: 'r'.
    (exc := exc truncate) nextPutAll: './lib/*'.
    exc := exc reset.
    run := FileStream popen: ('cpio -D /usr -u -i -d -m -E ',
			      exc) dir: 'w'.
    run nextPutAll: (pipe contents)
    pipe close.
    run close.
    pipe := FileStream popen: ('rpm2cpio ', home, '/',
			       (pkg := 'kernel-modules-', kernel,
				'.rpm')) dir: 'r'.
    run := FileStream popen: 'cpio -D /usr -u -i -d -m' dir: 'w'.
    ('Installing ', pkg, '...') displayNl.
    run nextPutAll: (pipe contents)
    pipe close.
    run close.
    pipe := FileStream popen: ('rpm2cpio ', home, '/',
			       (pkg := 'kernel-modules-extra-', kernel,
				'.rpm')) dir: 'r'.
    (exc := exc truncate) nextPutAll: './etc/*'.
    exc := exc reset.
    run := FileStream popen: ('cpio -D / -u -i -d -m -E ',
			      exc) dir: 'w'.
    ('Installing ', pkg, '...') displayNl.
    run nextPutAll: (pipe contents)
    pipe close.
    run close.
    pipe := FileStream popen: ('rpm2cpio ', home, '/', pkg) dir: 'r'.
    (exc := exc truncate) nextPutAll: './lib/*'.
    exc close.
    run := FileStream popen: ('cpio -D /usr -u -i -d -m -E ',
			      exc) dir: 'w'.
    run nextPutAll: (pipe contents)
    pipe close.
    run close.
    (File path: (exc name)) remove.
    pipe := FileStream popen: ('rpm2cpio ', home, '/',
			       (pkg := 'kernel-modules-internal-', kernel,
				'.rpm')) dir: 'r'.
    run := FileStream popen: 'cpio -D /usr -u -i -d -m' dir: 'w'.
    ('Installing ', pkg, '...') displayNl.
    run nextPutAll: (pipe contents)
    pipe close.
    run close.
] value.

[ | file stream bins initrd ret |
    'Finishing installation...' displayNl.
    bins := ReadStream on: ('update-initramfs -b ''/boot'' -c -k |',
			    'mkinitcpio -g ''initrd.img-',
			    kernel, ''' -k |',
			    'dracut --kver ''', kernel,
			    ''' ''/boot/initrd.img-''').
    stream := ReadStream on: path.
    ret := false.
    [ stream atEnd not and: [ ret not. ]. ] whileTrue: [ | path |
	path := stream upTo: $:.
	[
	    (ret := (File path: (path, '/',
	     ((initrd := bins upTo: $|) copyReplacingRegex:
	      ' .*' with: ''))) exists) or:
	    [ bins atEnd. ].
	] whileFalse.
	bins := bins reset.
    ].
    ret ifFalse: [
	('Couldn''t find an initial RAM disk generator. ',
	 'You should perform this action manually.',
	 (Character nl asString)) displayOn: stderr.
	initrd := ': '.
    ].
    Smalltalk system:
    ('( ln -f ''/lib/modules/', kernel, '/vmlinuz'' ''/boot/vmlinuz-', kernel, ''' || ',
    'cp -f ''/lib/modules/', kernel, '/vmlinuz'' ''/boot/vmlinuz-', kernel, ''' ; ',
    'ln -f ''/lib/modules/', kernel, '/System.map'' ''/boot/System.map-', kernel, ''' || ',
    'cp -f ''/lib/modules/', kernel, '/System.map'' ''/boot/System.map-', kernel, ''' ; ',
    'ln -f ''/lib/modules/', kernel, '/config'' ''/boot/config-', kernel, ''' || ',
    'cp -f ''/lib/modules/', kernel, '/config'' ''/boot/config-', kernel, ''' ; ',
    initrd, '''', kernel, ''' ; ',
    'grub-mkconfig -o ''/boot/grub/grub.cfg'' ) > /dev/null 2>&1').
    (file := File path: '/vmlinuz') exists ifTrue: [
	file remove.
    ].
    file symlinkFrom: ('/boot/vmlinuz-', kernel).
    (file := File path: '/initrd.img') exists ifTrue: [
	file remove.
    ].
    file symlinkFrom: ('/boot/initrd.img-', kernel).
] value.
packages do: [ :pkg |
    pkg remove.
].
[ | answer |
    ('Installation is complete!',
     'Would you like to restart the system now? [n] ') display.
    (((answer := stdin nextLine) notNil and: [
	answer size > 0. ]) and: [
	(answer asUppercase at: 1) = $Y. ]) ifTrue: [
	Smalltalk system: '( shutdown -r now & ) < /dev/null > /dev/null 2>&1'. ].
] value.
