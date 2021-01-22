## Git Tag + Tar; Reproducibility in Artifact Creation

[tar-sz](https://github.com/sambacha/tar-sz)

> Generate a plain-text, encrypted archive that is secured using the public key of a particular GitHub user.

- ssh-tgz
- tgz

## ssh-tgz

deterministic and reproducible self-composing and encrypted artifact generator.
Uses GitHub SSH keys to encrypt and decrypt

### Archive and Secure

Usage is _similar_ to `tar`.

```bash
ssh-tgzx github-username archive-file [files | directories]
```

### Extract

Send the file to user who owns the identity and they simply:

```bash
bash ./archive-file identity-file
```

### List

```bash
bash ./archive-file identity-file t
```

### Example

#### Create secure archive

To archive some files to send to me:

```bash
ssh-tgzx $GITHUB_USERNAME private.tgzx private-folder secret-file
```

It is (relatively) safe to send the file to me via insecure channels.

### Extract

I can extract is using:

```bash
bash ./private.tgzx ~/.ssh/id_rsa
```

### List

Or just list the contents:

bash ./private.tgzx ~/.ssh/id_rsa t

## tgzx

## Archive and Secure

Usage is _similar_ to `tar`.

```bash
tgzx archive-file [files | directories]
```

## Extract

```bash
./archive-file
```

### Example

#### Create secure archive

```bash
#!/usr/bin/env bash
# SPDX-License-Identifier: ISC
tgzx() {
	( ${#} >= 2; ) || { echo 'usage: tgzx archive-file [files | directories]'; return 1; }
	# shellcheck disable=SC2016
	printf '#!/usr/bin/env bash\ntail -n+3 ${0} | openssl enc -aes-256-cbc -d -a | tar ${1:-xv}z; exit\n' >"${1}"
	tar zc "${@:2}" | openssl enc -aes-256-cbc -a -salt >>"${1}" && chmod +x "${1}"
}
```

```bash
tgzx ssh.tgzx .ssh
```

#### Extract

```bash
./ssh.tgzx
```

#### List

```bash
./ssh.tgzx t
```

### Timezone RFC Table

| **RFC 822:**<br>_RFC 822 formatted date_             | Thu, 01 Jan 1970 00:00:00 +0000                  |
| ---------------------------------------------------- | ------------------------------------------------ |
| **ISO 8601:**<br>_ISO 8601 formatted date_           | 1970-01-01T00:00:00+00:00<br>1970-01-01 00:00:00 |
| **UNIX Timestamp:**<br>_seconds since Jan 1 1970_    | <br>00000000                                     |
| **Mac Timestamp:**<br>_seconds since Jan 1 1904_     |                                                  |
| **Microsoft Timestamp:**<br>_days since Dec 31 1899_ |                                                  |
| **FILETIME:**<br>_100-nanoseconds since Jan 1 1601_  | 0                                                |

### Time Normalization

Convert the "yyyymmddhh" string in argument \$1 to "yyyy-mm-dd hh:00" and
pass the result to 'date --rfc-3339=seconds' to normalize the date.
The date is interpreted in the timezone specified by the value that
the "TZ" environment variable was at first invocation of the script.

Example 1: 2015-12-10 10:00 PST (UTC-0800)
\$ env TZ='America/Los_Angeles' ./utcdate 2015121010
2015121018

### Deterministic Artifact Creation using GNU Tar

Empty Directory is created and archived to be embedded within

```bash
$ mkdir -p build/.emptydir
$ tar --owner=0 --group=0 --numeric-owner -cf pkg.tar build/.emptydir
$ tar --owner=0 --group=0 --numeric-owner -cf product.tar build
```

Full example The recommended way to create a Tar archive is thus:

```bash
$ tar --sort=name \
      --mtime="@${SOURCE_DATE_EPOCH}" \
      --owner=0 --group=0 --numeric-owner \
      --pax-option=exthdr.name=%d/PaxHeaders/%f,delete=atime,delete=ctime \
      -cf product.tar build
```
