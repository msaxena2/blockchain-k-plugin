This test module imports the various hooks we define here.
Its syntax is just a list of Bytes/String values.
This allows us to have programs which consist of lists
of hook invocations, so that we can test that the hook
outputs evaluate as we expect.

```k
requires "krypto.k"

module TEST-DRIVER
  imports BYTES
  imports KRYPTO

  syntax Data     ::= Bytes | String
  syntax DataList ::= List{Data, ""}

  configuration <k> $PGM:DataList </k>
endmodule
```
