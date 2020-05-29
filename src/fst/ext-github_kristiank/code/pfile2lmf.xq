xquery version "3.1";
declare namespace map = "http://www.w3.org/2005/xpath-functions/map";
import module namespace functx = 'http://www.functx.com';
import module namespace pfile = 'http://keeleleek.ee/pextract/pfile' at 'libs/pextract-xml/lib/pfile.xqm';
import module namespace daffodil = "edu.illinois.ncsa.daffodil" at "libs/basex-daffodil/daffodil.xqm";
declare namespace pextract = "http://keeleleek.ee/pextract";
declare namespace lmf = "lmf";


(:~
 Simple example for transforming a pfile to LMF Paradigm Patterns
 @author Kristian Kankainen
 @copyright MTÜ Keeleleek 2017
 :)

(: Project setup :)
let $lang := "vot"
let $base := file:parent(static-base-uri())
let $daffodil-bin := $base || "libs/daffodil-2.0.0/bin/daffodil"
let $dfdl-parser-bin := $base || "libs/dfdl-pextract-schema/pextract.dfdl.xsd.bin"

(: DFDL parser :)
let $dfdl-parse := daffodil:daffodil-cmd-use-saved-parser($daffodil-bin, 
                      $dfdl-parser-bin, "parse", ?, "-", "utf8")

let $pfiles-dir := concat($base, "../data/pextract/") => file:resolve-path()
let $pfiles     := file:children($pfiles-dir)[ends-with(.,".p")]

for $pfile in $pfiles
  let $pfile-name     := file:name($pfile)
  let $lmf-filename   := replace($pfile-name, ".p$", ".lmf")
  let $part-of-speech := replace($pfile-name, "^"||$lang||"-(.+).p$", "$1")
  let $pfile-xml      := $dfdl-parse($pfile)

  let $dtdVersion := "16"
  
  (: GlobalInformation :)
  let $label := "Votic automatically extracted morphological paradigms"
  let $comment := "The morphological paradigms has been extracted with the pextract tool."
  let $author := "Kristian Kankainen"
  let $languageCoding := "ISO 639-3"
  
  let $lmf :=
    <LexicalResource dtdVersion="{$dtdVersion}">
      <Lexicon>
      <GlobalInformation>
        <feat att="label" val="{$label}"/>
        <feat att="comment" val="{$comment}"/>
        <feat att="author" val="{$author}"/>
        <feat att="languageCoding" val="{$languageCoding}"/>
      </GlobalInformation>
      <feat att="language" val="{$lang}"/>
      {
        (: morphological patterns section :)
        for $paradigm in $pfile-xml/pextract:paradigm-file/pextract:paradigm
          return pfile:paradigm-as-lmf-pattern($paradigm, $part-of-speech)
        ,
        (: lexical entries section :)
        for $paradigm in $pfile-xml/pextract:paradigm-file/pextract:paradigm
          return pfile:paradigm-as-lmf-lexical-entries($paradigm, $part-of-speech)
      }
      </Lexicon>
    </LexicalResource>
  
  let $lmf-path := file:resolve-path($base || "../data/lmf.xml")
  
  return
    file:write($lmf-path, $lmf)