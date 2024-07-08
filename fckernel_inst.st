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
[ | path ret |
    path := ReadStream on: (Smalltalk getenv: 'PATH').
    ret := false.
    [ (path atEnd not) and: [ ret not. ]. ] whileTrue: [
	ret := (File path: ((path upTo: $:), '/rpm2cpio')) exists.
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
host := 'http://mirrors.edge.kernel.org/fedora-buffet/fedora/linux/development/rawhide/Everything/x86_64/os/Packages'.
kernel := ReadStream on: (((NetClients.URL fromString:
			    (host, '/k/')) contents =~
			    'kernel-core.*') match).
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
					(host, '/k/', name)) contents).
    fd close.
    'Verifying integrity...' displayNl.
    ((fd := pkg open: 'r') contents hash) = (url contents hash) ifFalse: [
	('Unmatched hashes. Aborting...', (Character nl asString))
	displayOn: stderr.
	ObjectMemory quit: -1.
    ].
    fd close.
].
[ | pipe exc run pkg |
    pipe := FileDescriptor popen: ('rpm2cpio ', home,
				   (pkg := '/kernel-core-', kernel,
				   '.rpm')) dir: 'r'.
    exc := FileDescriptor popen: 'cat' dir: 'w'.
    run := FileDescriptor popen: ('cpio -D / -u -i -d -m -E /dev/fd/',
				  (exc fd asString)) dir: 'w'.
    './usr/*' displayOn: exc.
    ('Installing', (pkg replaceFrom:
    1 to: 1 with: ' ' startingAt: 1), '...') displayNl.
    pipe displayOn: run.
    pipe close.
    run close.
    pipe := FileDescriptor popen: ('rpm2cpio ', home,
				   '/kernel-core-', kernel,
				   '.rpm') dir: 'r'.
    exc := FileDescriptor popen: 'cat' dir: 'w'.
    run := FileDescriptor popen: ('cpio -D /usr -u -i -d -m -E /dev/fd/',
				  (exc fd asString)) dir: 'w'.
    './lib/*' displayOn: exc.
    pipe displayOn: run.
    pipe close.
    run close.
    pipe := FileDescriptor popen: ('rpm2cpio ', home,
				   (pkg := '/kernel-modules-', kernel,
				   '.rpm')) dir: 'r'.
    run := FileDescriptor popen: 'cpio -D /usr -u -i -d -m' dir: 'w'.
    ('Installing', (pkg replaceFrom:
    1 to: 1 with: ' ' startingAt: 1), '...') displayNl.
    pipe displayOn: run.
    pipe close.
    run close.
    pipe := FileDescriptor popen: ('rpm2cpio ', home,
				   (pkg := '/kernel-modules-extra-', kernel,
				   '.rpm')) dir: 'r'.
    run := FileDescriptor popen: ('cpio -D / -u -i -d -m -E /dev/fd/',
				  (exc fd asString)) dir: 'w'.
    './etc/*' displayOn: exc.
    ('Installing', (pkg replaceFrom:
    1 to: 1 with: ' ' startingAt: 1), '...') displayNl.
    pipe displayOn: run.
    pipe close.
    run close.
    pipe := FileDescriptor popen: ('rpm2cpio ', home,
				   '/kernel-modules-extra-', kernel,
				   '.rpm') dir: 'r'.
    run := FileDescriptor popen: ('cpio -D /usr -u -i -d -m -E /dev/fd/',
				  (exc fd asString)) dir: 'w'.
    './lib/*' displayOn: exc.
    pipe displayOn: run.
    pipe close.
    run close.
    exc close.
    pipe := FileDescriptor popen: ('rpm2cpio ', home,
				   (pkg := '/kernel-modules-internal-', kernel,
				   '.rpm')) dir: 'r'.
    run := FileDescriptor popen: 'cpio -D /usr -u -i -d -m' dir: 'w'.
    ('Installing', (pkg replaceFrom:
    1 to: 1 with: ' ' startingAt: 1), '...') displayNl.
    pipe displayOn: run.
    pipe close.
    run close.
] value.

'Finishing installation...' displayNl.
Smalltalk system:
('( ln -f ''/lib/modules/', kernel, '/vmlinuz'' ''/boot/vmlinuz-', kernel, ''' || ',
'cp -f ''/lib/modules/', kernel, '/vmlinuz'' ''/boot/vmlinuz-', kernel, ''' ; ',
'ln -f ''/lib/modules/', kernel, '/System.map'' ''/boot/System.map-', kernel, ''' || ',
'cp -f ''/lib/modules/', kernel, '/System.map'' ''/boot/System.map-', kernel, ''' ; ',
'ln -f ''/lib/modules/', kernel, '/config'' ''/boot/config-', kernel, ''' || ',
'cp -f ''/lib/modules/', kernel, '/config'' ''/boot/config-', kernel, ''' ; ',
'update-initramfs -c -k ''', kernel, ''' ; ',
'grub-mkconfig -o ''/boot/grub/grub.cfg'' ) > /dev/null 2>&1').
[ | file |
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
	(answer size) > 0. ]) and: [
	(answer asUppercase at: 1) = $Y. ]) ifTrue: [
	Smalltalk system: 'shutdown -r now'. ].
] value.
