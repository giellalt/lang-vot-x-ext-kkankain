xquery version "3.0" encoding "UTF-8";
module namespace lmf = "http://keeleleek.ee/lmf";
import module namespace functx = 'http://www.functx.com';


(:~
 : Module for working with pextract-enhanced Lexical Markup Framework.
 :
 : @author Kristian Kankainen
 : @copyright MTÜ Keeleleek, 2018
 : @date 2018
 : @version 1.2
 : @see https://github.com/keeleleek/pextract2gf-votic/
 :)


(:~
 : Returns all TransformSet elements that contain the specified GrammaticalFeatures feats.
 : @since 1.0
 : @param $paradigm The MorphologicalPattern element
 : @param $grammaticalfeatures A map specifying the feature attributes and values
 : @return Sequnce of TransformSet elements
 :)
declare function lmf:get-transformsets-with-feats(
  $paradigm as element(MorphologicalPattern),
  $grammaticalfeatures as map(xs:string, xs:string)
) as element(TransformSet)*
{
  $paradigm/TransformSet[
    every $key in map:keys($grammaticalfeatures)
    satisfies ./GrammaticalFeatures/feat[@att=$key and @val=$grammaticalfeatures($key)]
  ]
};


(:~
 : Returns the wordform as split by pextract processes
 : @since 1.1
 : @param $processes A list of Process elements
 : @param $wordform The wordform to split
 : @param $suffixes List of suffixes (empty)
 : @return The sequence of the wordform split into parts
 :)
declare function lmf:split-by-processes($wordform, $processes, $suffixes) {
  (: base conditions :)
  if(count($processes)=0 or string-length($wordform)=0)
  then(for $part in ($wordform, $suffixes)
       where $part != ("", ())
       return $part
  )
  
  else( (: recurse conditions:)
    let $process := head($processes)
    return 
    if($process/feat[@att="processType" and @val="pextractAddConstant"])
    (: processType is a constant :)
    then(
      let $constant := $process/feat[@att="stringValue"]/@val/data()
      let $prefix   := functx:substring-before-last($wordform, $constant)
      
      return 
      (: make sure the substring-before-last was actually matched :)
      if(contains($wordform, $constant))
      then(
        let $suffix := substring($wordform, string-length($prefix)+string-length($constant)+1)
        return lmf:split-by-processes($prefix, tail($processes), ($constant, $suffix, $suffixes))
      )
      else(
        lmf:split-by-processes($wordform, tail($processes), ($suffixes))
      )
    )
    (: processType is not a constant :)
    else(
      lmf:split-by-processes($wordform, tail($processes), ($suffixes))
    )
  )
};



(:~ Returns the attested variable value sets of given paradigm :)
declare function lmf:get-attested-var-values(
  $paradigm as element(MorphologicalPattern)
) as element(AttestedParadigmVariableSet)*
{
  $paradigm/AttestedParadigmVariableSets/AttestedParadigmVariableSet
};



(:~ Returns a list of recreated word-forms of given TransformationSet (e.g. paradigm cell) :)
declare function lmf:get-attested-wordforms(
  $cell as element(TransformSet),
  $attested-values as element(AttestedParadigmVariableSet)+
) as xs:string+ {
  let $wordform-list :=
    for $attested-value-set in $attested-values
      let $wordform-parts := 
        for $process in $cell/Process
	  let $process-type := $process/feat[@att="processType"]/@val/data()
          return
	    switch ($process-type)
	    case "pextractAddConstant"
	      return $process/feat[@att="stringValue"]/@val/data()
	    case "pextractAddVariable"
	      return
	      let $var-num := $process/feat[@att="variableNum"]/@val/data()
	      return $attested-value-set/feat[@att=$var-num]/@val/data()
	    default return ("ERROR") (: @todo: throw error :)
	    
        return string-join($wordform-parts)
      return $wordform-list
};





(:~
 : Checks for consistency between listed paradigm patterns for lemmas and whether
 : they actually exist.
 : @since 1.1
 : @param  $lmf The resource to check
 : @return List of paradigm pattern names not existing or empty list for consistency
 :)
declare function lmf:check-if-listed-patterns-exist($lmf) {
  let $listed-patterns := $lmf//LexicalEntry/@morphologicalPatterns/data()
  let $distinct-listed-patterns := distinct-values(
        for $pattern-ids in $listed-patterns
          for $pattern-id in tokenize($pattern-ids, " ")
            return if(exists($lmf//MorphologicalPattern[./feat[@att="id" and @val=$pattern-id]]))
                   then()
                   else($pattern-id)
        )
  for $pattern-id in $distinct-listed-patterns
    return $pattern-id
};




(:~ 
 : Returns the MorphologicalPattern with given id
 : @since 1.2
 : @param $pattern-id as xs:string
 : @param $lmf
 : @return element(MorphologicalPattern)
 :)
declare function lmf:get-morphologicalpattern-by-id(
  $pattern-id as xs:string,
  $lmf as element(LexicalResource)
) as element(MorphologicalPattern)*
{
  $lmf//MorphologicalPattern[feat[@att="id" and @val=$pattern-id]]
};




(:~
 : Returns the wordform(s) with the specified grammatical features.
 : @since 1.2
 : @param $feats-map A map specifying the feature attributes and values
 : @param $lexicalentry the lexical entry
 : @return zero or more wordforms as xs:string*
 :)
declare function lmf:get-wordform-by-feats(
  $feats-map as map(xs:string, xs:string),
  $lexicalentry as element(LexicalEntry)
) as xs:string*
{
  $lexicalentry/WordForm[
    every $key in map:keys($feats-map)
    satisfies ./feat[@att=$key and @val=$feats-map($key)]
  ]/feat[@att = "writtenForm"]/@val/data()
};




(:~
 : Returns a generalized paradigm pattern of the input paradigm as discussed in:
 : "A Computational Model for the Linguistic Notion of Morphological Paradigm"
 : by Silfverberg, Miikka, Ling Liu & Mans Hulden (2018)
 : @since 1.2
 : @param $morphologicalpattern as MorphologicalPattern
 : @return GeneralMorphologicalPattern
 :)
declare function lmf:get-general-morphological-pattern(
  $morphologicalpattern as element(MorphologicalPattern)
) as element(GeneralMorphologicalPattern)
{
  let $orderedtransformsets := 
    for $sortedgramfeat in $morphologicalpattern/TransformSet
      order by string-join(sort(
        (:$sortedgramfeat/GrammaticalFeatures/feat/@val/data():)
        for $feat in $sortedgramfeat/GrammaticalFeatures/feat
            return concat($feat/@att/data(), "=", $feat/@val/data())
      ), " ")
      return $sortedgramfeat
  let $enumeratedconstants := 
    <enumeratedconstants>{
      for $process at $enum in distinct-values(
          $orderedtransformsets/Process/feat[@att="stringValue"]/@val/data())
        return <process><value>{$process}</value><enum>{$enum}</enum></process>
    }</enumeratedconstants>
  return copy $generalpattern := $morphologicalpattern
  modify (
    rename node $generalpattern as "GeneralMorphologicalPattern",
    for $constantstringvalue in $generalpattern//Process/feat[@att="stringValue"]/@val
      return replace value of node $constantstringvalue
             with $enumeratedconstants/process[value=$constantstringvalue]/enum/data()
  )
  return $generalpattern
};
