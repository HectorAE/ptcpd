<!--
SPDX-FileCopyrightText: 2016, 2025 Hector A. Escobedo <hae@dry.email>
SPDX-License-Identifier: GPL-3.0-only
-->

# Haskell PTCP Server

The Plain Text Chat Protocol is defined as a TCP-based application layer
protocol that provides group communication without overhead. Any data received
by the PTCP server from a client is broadcast to all other connected clients
unaltered. In this sense it is similar to the Echo Protocol, except that it is
many-to-many instead of one-to-one. The standard port number for PTCP is port
7034.

`ptcpd` is an implementation of the server-side PTCP component in Haskell. It
is currently in beta.

`netcat` is the recommended PTCP client.

## License and copyright information

This is a free and open source software project: you may redistribute and/or modify it under the terms of the
GNU General Public License Version 3. This program is distributed in the hope that it will be useful, but
WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR
PURPOSE. The full terms are available in text files included in the `LICENSES` directory.

This project conforms with the [REUSE Specification](https://reuse.software/spec-3.3/) to enable automatically
generating an [SPDX](https://spdx.dev/) software bill of materials.
