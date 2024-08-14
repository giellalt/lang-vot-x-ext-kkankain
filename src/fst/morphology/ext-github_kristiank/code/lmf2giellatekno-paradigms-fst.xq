xquery version "3.0" encoding "UTF-8";
import module namespace pjson = "http://keeleleek.ee/pextract/pjson" at "./karp-json.xqm";
import module namespace lmf = "http://keeleleek.ee/lmf" at "./lmf.xqm";
import module namespace giellatekno = "http://giellatekno.uit.no" at "./giellatekno.xqm";


(:~
 : This script converts the morphological paradigm patterns in the LMF lexical 
 : resource into a FST representation used in the Giellatekno infrastructure.
 : The code draws inspiration from the work of Forsberg, M and Hulden, M. (2016)
 : Learning Transducer Models for Morphological Analysis from Example Inflections
 : In Proceedings of StatFSM. Association for Computational Linguistics.
 : (http://anthology.aclweb.org/W16-2405)
 : 
 : @author Kristian Kankainen
 : @version 1.0
 :)

(: Helper function that aligns two TransformSets and inserts needed Constants :)
declare function local:align-transformsets(
  $upper as element(TransformSet),
  $lower as element(TransformSet),
  $i as xs:integer
) as element(TransformSet) {
  
(:return string-join((
      "[0:0]",
      for $process at $num in $transformset/Process
        return
        switch ($process/feat[@att="processType"]/@val/data())
        case "pextractAddVariable" return
          "[" || $fst-paradigm-id || "=var" || $num || "]"
        case "pextractAddConstant" return
          let $lower := if(exists($lemma/Process[$num]/feat[@att="stringValue"]/@val/data()))
                        then("{" || $lemma/Process[$num]/feat[@att="stringValue"]/@val/data() || "}")
                        else("0")
          let $upper := "{" || $process/feat[@att="stringValue"]/@val/data() || "}"
          return "[" || $upper || ":" || $lower || "]"
        default return ()
      ,"[0:0]",
      "0:[" || '"' || giellatekno:paradigm-to-lexc-tag($paradigm) || '" '
            || $gt-pos || " " || $gt-num || " " || $gt-case
            || "]"
    ), " "):)
};

(: Read in the LMF :)
let $lmf := doc("../data/lmf.xml")


let $lemma-feats := map {"grammaticalNumber":"singular", "grammaticalCase":"nominative"}

let $fst-paradigms :=
  for $paradigm in $lmf//MorphologicalPattern
  let $paradigm-id     := $paradigm/feat[@att="id"]/@val/data()
  let $pos             := $paradigm/feat[@att="partOfSpeech"]/@val/data()
  let $gt-pos          := '"+' || $giellatekno:get-fst-pos($pos) || '"'
  let $fst-paradigm-id := $paradigm-id || $giellatekno:get-fst-pos($pos)
  let $fst-define      := "define " || $fst-paradigm-id
  let $lemma      := lmf:get-transformsets-with-feats($paradigm, $lemma-feats)
                     => giellatekno:regularize-transformset()
  let $fst-cases  := for $transformset in $paradigm/TransformSet ! giellatekno:regularize-transformset(.)
    let $case := $transformset/GrammaticalFeatures/feat[@att = "grammaticalCase"]/@val/data()
    let $gt-case := '"+' || $giellatekno:get-giella-term($case) || '"'
    let $num := $transformset/GrammaticalFeatures/feat[@att = "grammaticalNumber"]/@val/data()
    let $gt-num := '"+' || $giellatekno:get-giella-term($num) || '"'
    return string-join((
      for $process at $num in $transformset/Process
        return
        switch ($process/feat[@att="processType"]/@val/data())
        case "pextractAddVariable" return
          "[" || $fst-paradigm-id || "=var" || $process/feat[@att="variableNum"]/@val/data() || "]"
        case "pextractAddConstant" return
          let $lower := if($lemma/Process[$num]/feat[@att="stringValue"]/@val/data() != "")
                        then("{" || $lemma/Process[$num]/feat[@att="stringValue"]/@val/data() || "}")
                        else("0")
          let $upper := if($process/feat[@att="stringValue"]/@val/data() != "")
                        then("{" || $process/feat[@att="stringValue"]/@val/data() || "}")
                        else("0")
          return "[" || $upper || ":" || $lower || "]"
        default return ()
      ,
      "0:[" || '"' || giellatekno:paradigm-to-lexc-tag($paradigm) || '" '
            || $gt-pos || " " || $gt-num || " " || $gt-case
            || "]"
    ), " ")
  let $fst-cases-body := string-join($fst-cases, " |" || out:nl())
  
  return $fst-define || " " || $fst-cases-body || ";" || out:nl() || out:nl()
  
let $fst-header := 'define Alph "a"|"b"|"c"|"d"|"d̕"|"e"|"f"|"f̕"|"g"|"h"|"h̕"|"i"|"j"|"k"|"l"|"l̕"|"m"|"n"|"n̕"|"o"|"p"|"p̕"|"r"|"r̕"|"s"|"s̕"|"š"|"t"|"t̕"|"č"|"u"|"v"|"v̕"|"y"|"z"|"z̕"|"ž"|"õ"|"ä"|"ö"|"ü";'

let $fst-paradigm-vars :=
  for $paradigm in $lmf//MorphologicalPattern
    let $paradigm-id     := $paradigm/feat[@att="id"]/@val/data()
    let $pos             := $paradigm/feat[@att="partOfSpeech"]/@val/data()
    let $fst-paradigm-id := $paradigm-id || $giellatekno:get-fst-pos($pos)
    for $transformset in $paradigm/TransformSet
    let $case := $transformset/GrammaticalFeatures/feat[@att = "grammaticalCase"]/@val/data()
    let $gt-case := '"+' || $giellatekno:get-giella-term($case) || '"'
    let $num := $transformset/GrammaticalFeatures/feat[@att = "grammaticalNumber"]/@val/data()
    let $gt-num := '"+' || $giellatekno:get-giella-term($num) || '"'
    return 
      for $process in $transformset/Process
        return
        switch ($process/feat[@att="processType"]/@val/data())
        case "pextractAddVariable" return
          let $num := $process/feat[@att="variableNum"]/@val/data()
          return 
          "define " || $fst-paradigm-id || "=var" || $num || " Alph+;"
        default return ()

let $fst-define-paradigms :=
  "define Gconstrained " ||
  string-join((
    for $paradigm in $lmf//MorphologicalPattern
      let $paradigm-id     := $paradigm/feat[@att="id"]/@val/data()
      let $pos             := $paradigm/feat[@att="partOfSpeech"]/@val/data()
      let $fst-paradigm-id := $paradigm-id || $giellatekno:get-fst-pos($pos)
      return $fst-paradigm-id
    ), " | ")
  || ";"

let $fst-footer := $fst-define-paradigms || out:nl() ||
'regex Gconstrained;
invert'

let $fst := $fst-header || 
            out:nl() || 
            out:nl() || 
            string-join(distinct-values($fst-paradigm-vars), out:nl()) ||
            out:nl() || 
            out:nl() || 
            string-join($fst-paradigms, out:nl()) ||
            out:nl() ||
            out:nl() ||
            $fst-footer

let $filename := "/home/kristian/Projektid/MA-thesis/data/giellatekno/morphology/paradigms.xfscript"

return file:write-text($filename, $fst)