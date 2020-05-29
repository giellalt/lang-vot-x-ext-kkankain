# BaseX-Daffodil

A simple wrapper for using DFDL with Daffodil in XQuery on BaseX.

The capabilities of the module functions should be obvious when 
consulting Daffodil's command help (``daffodil --help``)

This is **work in progress** and all comments are welcome.



## Usage examples

Basically it is meant to be used with partial instantiation

```XQuery
import module namespace daffodil = "edu.illinois.ncsa.daffodil"
  at "basex-daffodil/daffodil.xqm";

let $daffodil-bin := "daffodil-2.0.0/bin/daffodil"

let $my-parser := daffodil:daffodil-cmd-use-schema(
    $daffodil-bin, ?, "parse", ?, "-", "utf-8"
  )
  
(: use "-" instead of an $outfile name to read in the parsed document :)

let $xml := $my-parser("dfdl-schema-file.xsd", "input-file")


(: use a filename to simply let daffodil save it's output on disk :)
let $my-parse-to-file := daffodil:daffodil-cmd-use-schema(
    $daffodil-bin, "dfdl-schema-file.xsd", "parse", ?, "utf-8"
)

for $file-name in $some-dir-listing
  return
    $my-parse-to-file($file-name || ".xml")
```

It is possible to compile and save a DFDL schema with

```XQuery
daffodil:save-parser($daffodil, $schema, $outfile as xs:string?)

(:~
  if no $outfile is specified, a default value of 
    $schema || ".bin"
  will be used
:)
```

and use it with

```XQuery
daffodil:daffodil-cmd-use-saved-parser(
    $daffodil-bin, $parser, $action, 
    $infile, $outfile, $sys-encoding as xs:string?
  )
```
