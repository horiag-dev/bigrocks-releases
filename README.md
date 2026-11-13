# Big Rocks First — releases

Encrypted release packages for the Big Rocks First local service, used by its
installer and its built-in updater. Each package is encrypted (scrypt +
AES-256-GCM); it is useless without the release password.

## Install (authorized users)

```sh
curl -fsSL https://raw.githubusercontent.com/horiag-dev/bigrocks-releases/main/install.sh | sh
```

It asks for the release password, installs into `~/big-rocks-first`, and from
then on the app updates itself (an **Update** button next to the version).

## Legal

© 2026 Big Rocks First. All rights reserved. The software is **not open
source**. It is proprietary and confidential, and no license is granted to use,
copy, modify, distribute, decrypt or reverse engineer it without the copyright
holder's written permission.
