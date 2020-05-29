(:~ 
  
  A simple wrapper module for using Daffodil with BaseX.
  
  @author: Kristian Kankainen
  @copyright: MTÜ Keeleleek

:)

module namespace daffodil = "edu.illinois.ncsa.daffodil";



(:~ 
  Compiles a DFDL schema and saves it in binary form.
  @param: $daffodil the path to the daffodil binary
  @param: $schema   the path to the dfdl schema
  @param: $outfile  the path where to save the compiled parser
:)
declare function daffodil:save-parser($daffodil, $schema, $outfile as xs:string?)
{
  let $outfile := if($outfile)
                  then($outfile)
                  else($schema || ".bin")
  
  return
  proc:system(
    $daffodil,
    (
      "save-parser",
      "--schema",
      $schema,
      $outfile
    )
  )
};



(:~ 
  Generic function for using daffodil with a saved parser.
  @param: $daffodil the path to the daffodil binary
  @param: $parser   the path to the saved parser
  @param: $action   parse or unparse
  @param: $infile   the path to the input file
  @param: $outfile  the path to the output tdml file
  @param: $sys-encoding the system's encoding
:)
declare function daffodil:daffodil-cmd-use-saved-parser
  ($daffodil, $parser, $action, $infile, $outfile, $sys-encoding as xs:string?)
{
  let $encoding := if($sys-encoding) then($sys-encoding) else("")
  
  let $pfile :=
    proc:system($daffodil,
                (: argument list :)
                ( $action,
                  "--parser", $parser,
                  "--output", $outfile,
                  $infile
                )
                (: options :)
                ,(map{"encoding":$encoding})
        )
  
  return
    if($outfile = "-")
    then(parse-xml($pfile))
    else($pfile) (: @todo: but this is empty :)
};



(:~ 
  Generic function for using daffodil with a DFDL schema.
  @param: $daffodil the path to the daffodil binary
  @param: $schema   the path to the DFDL schema
  @param: $action   parse or unparse
  @param: $infile   the path to the input file
  @param: $outfile  the path to the output tdml file
  @param: $sys-encoding the system's encoding
:)
declare function daffodil:daffodil-cmd-use-schema
  ($daffodil, $schema, $action, $infile, $outfile, $sys-encoding)
{
  let $encoding := $sys-encoding
  
  let $pfile := 
    proc:system($daffodil,
                (: argument list :)
                ( $action,
                  "--schema", $schema,
                  "--output", $outfile,
                  $infile
                )
                (: options :)
                ,(map{"encoding":$encoding})
    )
  
  return
    if($outfile = "-")
    then(parse-xml($pfile))
    else($pfile) (: @todo: but this is empty :)
};
