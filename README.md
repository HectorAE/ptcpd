Haskell PTCP Server
===================

The Plain Text Chat Protocol is defined as a TCP-based application layer
protocol that provides group communication without overhead. Any data received
by the PTCP server from a client is broadcast to all other connected clients
unaltered. In this sense it is similar to the Echo Protocol, except that it is
many-to-many instead of one-to-one. The standard port number for PTCP is port
7034.

`ptcpd` is an implementation of the server-side PTCP component in Haskell. It
is currently in beta.

`netcat` is the recommended PTCP client.
