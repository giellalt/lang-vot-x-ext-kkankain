xquery version "3.1";
declare namespace map = "http://www.w3.org/2005/xpath-functions/map";
import module namespace functx = 'http://www.functx.com';
(:import module namespace lmf = "http://keeleleek.ee/lmf" at "/home/kristian/Projektid/marfors/pextract-xml/lib/lmf.xqm";:)
import module namespace lmf = "http://keeleleek.ee/lmf" at "lmf.xqm";
declare namespace p = "http://keeleleek.ee/pextract";


(:~ 
 : This converts a pextract-lmf file into Grammatical Framework code.
 : 
 : @author Kristian Keeleleek
 : @version 1.0.0
 : @see https://github.com/keeleleek/pextract2gf-votic
 :)



(:~ Serialize the $params-map as a GF param statement
 : @since 1.0.0
 :)
declare function p:serialize-params ($params-map) as xs:string {
  string-join(
      (for $param-feature in map:keys($params-map)
         let $values := string-join(
             for $value in $params-map?($param-feature)
               return p:translate($grammatical-features, $value),
             " | ")
        return concat(
          "  ", p:translate($grammatical-features, $param-feature), " = ", $values, " ;")
      )
    , out:nl()
  )
};


(:~ Simple translation functionality using maps. This translates the
 :  given string to it's corresponding value in the map. If no corresponding
 :  key is found, the original string is returned.
 : @since 1.0.0
 :)
declare function p:translate($translation-map, $string)
{
  if($translation-map?($string))
  then($translation-map?($string))
  else($string)
};


(:~ Simple translation maps for stuff like 'singular' = 'Sg'
 : @since 1.0.0
 :)
declare variable $grammatical-features := map {
  "singular" : "Sg",
  "plural"   : "Pl",
  "grammaticalNumber" : "Number",
  "grammaticalCase"   : "Case"
};

declare variable $pos-to-gf-type := map {
  "commonNoun" : "Noun",
  "nn" : "Noun"
};




(:let $base-dir := file:parent(static-base-uri()):)
let $base-dir := "/tmp/"
(:let $lmf-file := doc($base-dir || "examples/generated-vot-lmf.xml"):)
let $lmf-file := doc("../data/lmf.xml")
let $lang     := $lmf-file//Lexicon/feat[@att="language"]/@val
let $lang-capitalized := functx:capitalize-first($lang)

(: @todo instead of just the first POS, loop through all :)
let $part-of-speeches := distinct-values($lmf-file//MorphologicalPattern//feat[@att="partOfSpeech"]/@val)[1]

(: we loop over pos for the sake of grouping all paradigms by their pos :)
for $part-of-speech in $part-of-speeches
return

  let $morphological-patterns := $lmf-file//MorphologicalPattern[./feat[@att="partOfSpeech" and @val=$part-of-speech]]
  
  let $gf-pos-name := p:translate($pos-to-gf-type, $part-of-speech)
  let $morpho-file := $base-dir || "Morpho" || $lang-capitalized || ".gf" 
  
  (: Generate the GF param section :)
  (: Collect a map of parameter feature names and values :)
  let $params-map := map:merge(
    let $grammatical-features := $morphological-patterns/TransformSet/GrammaticalFeatures
    for $label in distinct-values($grammatical-features/feat/@att)
      return map:entry(
        $label,
        distinct-values($grammatical-features/feat[@att=$label]/@val)
      )
  )
  
  return
  (
  file:write-text($morpho-file,
  
  string-join((
    "resource " || substring-before(file:name($morpho-file), ".gf") || " = {",
    "",
    (: the params list :)
    (: @todo type definitions should be outputted to ParamLang.gf file :)
    "param",
    p:serialize-params($params-map),
    "  NForm = NF Number Case ;",
    "",
    "oper",
    "  Noun : Type = {s : NForm => Str} ;",
    "",
    "------------------------------------------------",
    "-- Start of " || $gf-pos-name || " section",
    "------------------------------------------------",
    "",
    
    (: generate abstract and concrete functions for each paradigm :)
    for $paradigm in $morphological-patterns
      let $lemma-transformset := ($paradigm/TransformSet)[1] (: @todo: use msd instead :)
      let $attested-variables := lmf:get-attested-var-values($paradigm)[1]
      let $lemma := lmf:get-attested-wordforms($lemma-transformset,
                                       $attested-variables)
      let $lemma-capitalized := functx:capitalize-first($lemma)
      let $lemma-mk := "mk" || $lemma-capitalized
      let $variables-list := $lemma-transformset/Process/feat[@att="variableNum"]/@val
      let $first-attested-values := map:merge(
        for $variable in ($paradigm/AttestedParadigmVariableSets)[1]/AttestedParadigmVariableSet/feat
          return map:entry(
            xs:string($variable/@att),
            $variable/@val
          )
        )
      
      let $abstract-function := string-join((
        "  mk" || $lemma-capitalized || " : Str -> Noun = \" || $lemma || " -> " || out:nl(),
        "    case " || $lemma || " of {" || out:nl(),
        (: pattern match for appropriate case :)
        "      ",
        string-join((
            for $process in $lemma-transformset/Process
              (:let $operator := $process/feat[@att="operator"]/@val:)
              let $process-type := $process/feat[@att="processType"]/@val
              return
                switch($process-type)
                case "pextractAddVariable" return 
                  let $var-num := $process/feat[@att="variableNum"]/@val/data()
                  let $var-value := $attested-variables/feat[@att=$var-num]/@val/data()
                  return $var-value
                case "pextractAddConstant" return
                  let $const-value := $process/feat[@att="stringValue"]/@val/data()
                  return concat(
                           '"',$const-value,'"'
                         )
                default return () (: @todo: throw error :)

          ), " + ")
        , " => mk" || $lemma-capitalized || "Concrete " || string-join(
                    (for $var-num in $variables-list
                       return $attested-variables/feat[@att=$var-num]/@val/data()
                    ), " ") || " ;"
        , out:nl(),
        (: default case for inappropriate pattern match :)
        '      _ => Predef.error "Unsuitable lemma for ' || $lemma-mk || '"', out:nl(),
        "    } ;"
      ))
      
      let $concrete-function := string-join((
        "  mk" || $lemma-capitalized || "Concrete : ",
        string-join((
          for $i in (1 to count($variables-list)) return "Str"
          ), " -> "),
        " -> ",
        p:translate($pos-to-gf-type, $part-of-speech),
        " = \" || string-join((
          for $var-num in $variables-list
            return $attested-variables/feat[@att=$var-num]/@val/data()
          ), ",") || " -> " || out:nl(),
        "    { s =" || out:nl(),
        "      table {" || out:nl(),
        (: each TransformSet is written into a table row :)
        (: @todo: this should be refactorized as a separate function :)
        string-join((
          for $transformset in $paradigm/TransformSet
            return string-join((
              "        NF ",
              (: join grammatical features :)
              string-join((
              for $gram-feat in $transformset/GrammaticalFeatures/feat
                return $gram-feat/@val/data()
              ), " "),
              " => ",
              (: join pattern variables and constants :)
              (: variableNumbers are rewritten as their first attestation :)
              (: stringValues are written within quotation marks :)
              string-join((
                for $process in $transformset/Process
                (:let $operator := $process/feat[@att="operator"]/@val:)
                let $process-type := $process/feat[@att="processType"]/@val
                return
                  switch($process-type)
                  case "pextractAddVariable" return 
                    let $var-num := $process/feat[@att="variableNum"]/@val/data()
                    let $var-value := $attested-variables/feat[@att=$var-num]/@val/data()
                    return $var-value
                  case "pextractAddConstant" return
                    let $const-value := $process/feat[@att="stringValue"]/@val/data()
                    return concat(
                           '"',$const-value,'"'
                           )
                  default return () (: @todo: throw error :)
              ), " + ")
            ))
          ), " ;" || out:nl()),
        out:nl() || "      }" || out:nl(),
        "    } ;"
      ))
      
      return 
        string-join((
            $abstract-function,
            $concrete-function,
            ""
          ), out:nl() || out:nl() 
        )
    ,"}"
    ), out:nl()
  )
)
)