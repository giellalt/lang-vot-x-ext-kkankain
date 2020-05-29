xquery version "3.0" encoding "UTF-8";
import module namespace pjson = "http://keeleleek.ee/pextract/pjson" at "./karp-json.xqm";
import module namespace lmf = "http://keeleleek.ee/lmf" at "./lmf.xqm";
import module namespace giellatekno = "http://giellatekno.uit.no" at "./giellatekno.xqm";


(:~
 : This script is a proof-of-concept of the paradigm generalization method introduced in:
 : "A Computational Model for the Linguistic Notion of Morphological Paradigm" (Silfverberg, Miikka, Ling Liu & Mans Hulden. 2018)
 : 
 : @author Kristian Kankainen
 : @date 2018
 : @version 1.0
 :)

(: Read in the LMF :)
let $lmf := doc("../data/lmf.xml")

(: generalize all morphological patterns :)
let $general-morphological-patterns := $lmf//MorphologicalPattern ! lmf:get-general-morphological-pattern(.)

(: filter out distinct (unique) patterns :)
let $distinct-morphological-patterns :=
  for $pattern at $position in $general-morphological-patterns
    let $rest-of-generalpatterns := $general-morphological-patterns[position() > $position]
    return
    (: if there is another equal pattern in the rest :)
    if  ($rest-of-generalpatterns[deep-equal($pattern/TransformSet, ./TransformSet)])
    (: then don't return the pattern :)
    then()
    (: but if this is the only unique pattern, then return it :)
    else($pattern)

    
(: count general paradigms :)
let $num-of-distinct-patterns := count($distinct-morphological-patterns)

(: optimization :)
let $lexical-entries-and-their-general-pattern := 
  for $lexical-entry in $lmf//LexicalEntry
    return
    copy $new-entry := $lexical-entry
    modify (
      let $lemma := $lexical-entry/Lemma/feat[@att="writtenForm"]/@val/data()
      let $id := $lexical-entry/@morphologicalPatterns/data()
      let $lexical-entry-morphological-pattern :=
            lmf:get-morphologicalpattern-by-id(
              $lexical-entry/@morphologicalPatterns/data(),
              $lmf/LexicalResource
            )[1]
      let $lexical-entry-general-pattern := lmf:get-general-morphological-pattern(
        $lexical-entry-morphological-pattern
      )
          
      return (
        insert node $lexical-entry-general-pattern into $new-entry,
        insert node $lexical-entry-morphological-pattern into $new-entry
      )
    )
    return $new-entry

(: group paradigms that share general patterns and show their IDs :)
let $latex-tables :=
  for $general-pattern in $distinct-morphological-patterns
    let $pattern-id := $general-pattern/feat[@att="id"]/@val/data()
    let $specific-pattern := lmf:get-morphologicalpattern-by-id(
      $pattern-id,
      $lmf/LexicalResource
    )
    (: table section :)
      let $table-start := ("\begin{table}",
                           "\centering", 
                           "\begin{tabular}[p]{l l l}",
                           "ühisosajada &amp; muutvormimall &amp; tunnused \\",
                           "\hline"
                          )
    let $table-content := 
      for $transformset in $specific-pattern/TransformSet
        let $gramfeats := string-join((
          "\textsc{",
          $transformset/GrammaticalFeatures/feat/@val/data() ! $giellatekno:get-giella-term(.) ! lower-case(.),
          "} \\"), " "
        )
        let $pattern :=
          for $process in $transformset/Process
            return switch ($process/feat[@att="processType"]/@val/data())
              case "pextractAddVariable" return
                "$x_" || $process/feat[@att="variableNum"]/@val/data() || "$"
              default return
                $process/feat[@att="stringValue"]/@val/data()
         let $model-word :=
           for $process in $transformset/Process
            return switch ($process/feat[@att="processType"]/@val/data())
              case "pextractAddVariable" return
                "\underline{" || 
                lmf:get-attested-var-values($specific-pattern)[1]
                  /feat[@att = $process/feat[@att="variableNum"]/@val/data()]
                  /@val/data() || "}"
              default return
                $process/feat[@att="stringValue"]/@val/data()
         return concat(string-join($model-word, " "), " &amp; ", string-join($pattern, " + "), " &amp; ", $gramfeats)

        (: subordinate lexical entries section :)
    let $lexical-entries := 
      for $lexical-entry in $lexical-entries-and-their-general-pattern
        let $lemma := $lexical-entry/Lemma/feat[@att="writtenForm"]/@val/data()
        let $pattern-id := $lexical-entry/@morphologicalPatterns/data()
        
        return if  (deep-equal(
                      $lexical-entry//GeneralMorphologicalPattern/TransformSet,
                      $general-pattern/TransformSet))
               then("\textit{" || $lemma || "}")
               else()
               
    order by count($lexical-entries) descending
    
    let $sõnade := if(count($lexical-entries) > 1) then("sõnade ") else("sõna ")
    let $table-end := (
      "\end{tabular}",
      "\caption{Üldistatud muuttüüp " || $sõnade || string-join($lexical-entries, ", ") 
            || " ekstraheeritud tüüp" || $sõnade || " järgi.}",
      (: "\label{}" :)
      "\end{table}",
      "\clearpage",
      ""
    )
    let $latex-table := string-join((
      $table-start, $table-content, $table-end
    ), out:nl())

    return $latex-table

(:return string-join($latex-tables, out:nl()):)
return file:write-text(
    "/home/kristian/Projektid/MA-thesis/thesis/lmf-paradigms.tex",
    string-join($latex-tables, out:nl())
  )