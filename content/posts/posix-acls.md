---
title: POSIX ACLs by Example
description: >
  A practical set of notes on how to use POSIX ACLs (getfacl/setfacl)
summary: >
  A practical set of notes on how to use POSIX ACLs (getfacl/setfacl)
date: 2024-06-29
tags: ["shell", "getfacl", "setfacl", "linux", "cli", "filesystem"]
author: ["Marco Paganini"]
draft: false
---

## POSIX ACLs by example

POSIX ACL semantics integrate in unusual ways to the usual user/group/all permissions
most people are used on Linux filesystems. The manpage for `getfacl` and `setfacl` is
equally confusing. This is just a quick set of notes on how they work.

TL;DR:

```bash
setfacl -R -m default:u:paganini:rwX dir
setfacl -R -m u:paganini:rwX dir
```

Note that this will use the group setting as the mask (meaning, the file group
permissions dictate the highest access any ACL user can have to a file.)

More info:
https://www.usenix.org/legacy/publications/library/proceedings/usenix03/tech/freenix03/full_papers/gruenbacher/gruenbacher_html/main.html

This example should make it better to understand how it fits together:

```bash
$ echo haha >haha
$ ls -ltr haha
-rw-r--r-- 1 paganini paganini 5 Jan 25 18:40 haha
```

ACLs formatted as `[user|group|other]::[rwxX]` refer to the owning uid and gid of the file
and match directly (note the ::). They follow the user, group and other permission bits
of the file. Changing the file permissions will reflect directly here:

```bash
$ getfacl haha
# file: haha
# owner: paganini
# group: paganini
user::rw-
group::r--
other::r--
```

It's possible to give extra rights to a user into a file:

```bash
$ setfacl -m g:users:rw haha

$ ls -tlr haha
-rw-rw-r--+ 1 paganini paganini 5 Jan 25 18:40 haha

$ getfacl haha

# file: haha
# owner: paganini
# group: paganini
user::rw-
group::r--
group:users:rw-
mask::rw-
other::r--
```

Things to note:
* The "+" sign at the end of the display listing indicates that this file has an extended ACL.
* A new extended ACL was added for `group:users` (rw-).
* Note the appearance of the mask.

Now we change the mask:

```bash
$ setfacl -m 'm::r' haha
$ ls -ltr haha

-rw-r--r--+ 1 paganini paganini 5 Jan 25 18:40 haha

$ getfacl haha

# file: haha
# owner: paganini
# group: paganini
user::rw-
group::rw-                      # effective:r--
group:users:rw-                 # effective:r--
mask::r--
other::r--
```

Things to note:
* The `-m` changes the default mask to `r--`.
* The default mask affects **all named users** equally. It is ANDed with all permissions.
* The original owner of the file can always access it (no AND with the original mask).
* Changing the mask is the same as changing the group permissions via `chmod`, and vice-versa.
* Again, the owner of the file is not affected.

### General examples

* Files and directories under a directory will inherit the default ACL for the parent directory.
  * Setting the default ACL on a directory and subdirs: `setfacl -R -m default:u:paganini:rwX dir`
* Setting ACL for all files and subdirs: `setfacl -R -m u:paganini:rwX dir`
* Removing a specific ACL: `setfacl -R -x g:staff dir`
* Removing extended ACLs: `setfacl -R -b .`
* Removing default ACLs: `setfacl -R -k .`
* When using `rsync` add `-AX` to the command-line to copy ACLs and extended attributes.

Remember: The mask is ANDed with the permissions of all **named** users and
groups in the extended ACLs to give effective permissions to the file. With
extended ACLs, the file's group permission effectively limits the permissions
for all named users and groups.

If using ZFS, a filesystem must have the `acltype=posixacl` property set to
allow ACLs:

```bash
sudo zfs set acltype=posixacl pool/filesystem
```

### See all files with ACLs.

To find all files with ACLs under the current directory:

```bash
getfacl -Rs  . | perl -nle '
  if (/^# file: (.*)/) {
    print $1 =~ s{\\(\\|[0-7]{3})}{
      $1 eq "\\" ? "\\" : chr oct $1}ger
  }
```

