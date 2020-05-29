xquery version "3.0" encoding "UTF-8";
module namespace pfile = "http://keeleleek.ee/pextract/pfile";
declare namespace pextract = "http://keeleleek.ee/pextract";
import module namespace functx = 'http://www.functx.com';

(:~ 
 : Collection of functions for handling paradigm extract files.
 : 
 : @author Kristian Kankainen, MTÜ Keeleleek
 : @version 0.1
 :)



(:~ Returns the attested variable value sets of given paradigm :)
declare function pfile:get-attested-var-values(
  $paradigm as element(pextract:paradigm)
){
  $paradigm/pextract:variable-values
};



(:~ Returns the attested variable values of the given paradigm as a map. :)
declare function pfile:get-attested-var-values-maps(
  $paradigm as element(pextract:paradigm)
){
  let $return-list-of-maps := (
      for $variable-set in pfile:get-attested-var-values($paradigm)/pextract:variable-set
        let $attested-var-values-map := map:merge(
          for $variable in $variable-set/pextract:variable
            let $num := xs:integer($variable/pextract:variable-number/data())
            let $val := $variable/pextract:variable-value/string()
            return
              map:entry($num, $val)
        )
      return $attested-var-values-map
  )
  return $return-list-of-maps
};



(:~ Returns a list of recreated word-forms of given paradigm cell :)
declare function pfile:get-attested-wordforms(
  $cell as element(pextract:paradigm-cell),
  $attested-values as element(pextract:variable-values)
) as xs:string+ {
  let $pattern := $cell/pextract:pattern
  let $wordform-list :=
    for $attested-value-set in $attested-values/pextract:variable-set
      let $wordform-parts := 
        for $part in $pattern/pextract:pattern-part
          return
            if (matches($part, "\d+"))
            then ($attested-value-set/pextract:variable[./pextract:variable-number = $part]/pextract:variable-value)
            else ($part)
        
        return string-join($wordform-parts)
      return $wordform-list
};



(:~ Returns all morpho-syntactic descriptors of a given paradigm as a map :)
declare function pfile:get-paradigm-msd-map(
  $paradigm as element(pextract:paradigm)
)
{
  let $msds := $paradigm//pextract:msd-description
  let $msd-map := map:merge(
    let $keys := distinct-values($msds/pextract:feature/pextract:name)
    for $key in $keys
      let $values := distinct-values($msds/pextract:feature[./pextract:name = $key]/pextract:value)
      return map:entry($key, $values)
  )
  return $msd-map
};



(:~ Returns all morpho-syntactic descriptors of a given cell as a map :)
declare function pfile:get-cell-msd-map(
  $cell as element(pextract:paradigm-cell)
)
{
  let $msds := $cell/pextract:msd-description
  let $msd-map := map:merge(
    let $keys := distinct-values($msds/pextract:feature/pextract:name)
    for $key in $keys
      let $values := distinct-values($msds/pextract:feature[./pextract:name = $key]/pextract:value)
      return map:entry($key, $values)
  )
  return $msd-map
};




(:~ Returns all inherent morpho-syntactic descriptors of a given cell as a map :)
(: @todo: fill this place-holder :)
declare function pfile:get-inherent-type-msd-map(
  $cell as element(pextract:paradigm-cell),
  $type-system
)
{
  
};



(:~ Represent a pextract paradigm as a LMF Morphological Pattern :)
declare function pfile:paradigm-as-lmf-pattern(
  $paradigm as element(pextract:paradigm),
  $part-of-speech as xs:string
) as element(MorphologicalPattern)
{
  let $paradigm-lemma := pfile:get-attested-wordforms(
    ($paradigm//pextract:paradigm-cell)[1], (: @todo remove hardcoded selector :)
    pfile:get-attested-var-values($paradigm)
  )[1]
  let $paradigm-id := "as" || functx:capitalize-first($paradigm-lemma)
  let $paradigm-comment := concat('extract paradigm pattern for ', $paradigm-lemma)
  
  let $paradigm-attested-variables := pfile:get-attested-var-values-maps($paradigm)
  
  return 
  <MorphologicalPattern>
    <feat att="id" val="{$paradigm-id}" />
    <feat att="comment" val="{$paradigm-comment}" />
    <feat att="example" val="{$paradigm-lemma}" />
    <feat att="partOfSpeech" val="{$part-of-speech}" />
    <AttestedParadigmVariableSets>
      {
      for $attested-variable-set in $paradigm-attested-variables
        return
          <AttestedParadigmVariableSet>
            {
            map:for-each(
              $attested-variable-set,
              function ($key, $value) {<feat att="{$key}" val="{$value}" />}
            )
            }
          </AttestedParadigmVariableSet>
      }
    </AttestedParadigmVariableSets>
    {
      for $cell in $paradigm//pextract:paradigm-cell
        let $msd-feats := pfile:get-cell-msd-map($cell)
        return
          <TransformSet>
            <GrammaticalFeatures>
              {
                map:for-each(
                  $msd-feats,
                  function ($key, $value) {<feat att="{$key}" val="{$value}" />} )
              }
            </GrammaticalFeatures>
            {
              for $pattern-part in $cell//pextract:pattern/pextract:pattern-part
                return
                  <Process>
                  {
                    if(matches($pattern-part, "\d+"))
                    then(
                      (: the case it is a variable number :)
                      <feat att="operator" val="addVariable" />,
                      <feat att="processType" val="pextractAddVariable"/>,
                      <feat att="variableNum" val="{$pattern-part}" />
                    )
                    else(
                      (: the case it is a constant string :)
                      <feat att="operator" val="addConstant" />,
                      <feat att="processType" val="pextractAddConstant"/>,
                      <feat att="stringValue" val="{$pattern-part}" />
                    )
                  }
                </Process>
            }
          </TransformSet>
    }
  </MorphologicalPattern>
};



(:~ Represent all extracted wordforms in a pextract paradigm as LMF Lexical Entries :)
declare function pfile:paradigm-as-lmf-lexical-entries(
  $paradigm as element(pextract:paradigm),
  $part-of-speech as xs:string
) as element(LexicalEntry)+
{
  let $paradigm-lemma := pfile:get-attested-wordforms(
    ($paradigm//pextract:paradigm-cell)[1], (: @todo remove hardcoded selector :)
    pfile:get-attested-var-values($paradigm)
  )[1]
  let $paradigm-id := "as" || functx:capitalize-first($paradigm-lemma)
  let $paradigm-comment := concat('extract paradigm pattern for ', $paradigm-lemma)
  
  let $paradigm-attested-variables := pfile:get-attested-var-values-maps($paradigm)
  (: for instantiation :)
  for $instantiation in pfile:get-attested-var-values($paradigm)/pextract:variable-set
    let $instantiation-var-values := <pextract:variable-values>{$instantiation}</pextract:variable-values>
    return
      <LexicalEntry morphologicalPatterns="{$paradigm-id}">
        {(:<feat att="morphologicalPatterns" val="{$paradigm-id}" />:)}
        <feat att="partOfSpeech" val="{$part-of-speech}" />
        {
        let $paradigm-cells := $paradigm//pextract:paradigm-cell
        let $lemma := 
            <Lemma>
              <feat att="writtenForm"
                    val="{pfile:get-attested-wordforms($paradigm-cells[1], $instantiation-var-values)}"/>
            </Lemma>
        let $wordforms := for $cell in $paradigm-cells (: wordform :)
            let $msd-feats := pfile:get-cell-msd-map($cell)
            return
              <WordForm>
                { (: grammatical features section :)
                  map:for-each(
                    $msd-feats,
                    function ($key, $value) {<feat att="{$key}" val="{$value}" />} )
                  ,(: writtenForm section :)
                  let $written-form := pfile:get-attested-wordforms($cell, $instantiation-var-values)
                  return
                    <feat att="writtenForm" val="{$written-form}"/>
                }
              </WordForm>
        
        return ($lemma,$wordforms)
      }
      </LexicalEntry>
};




(:~ Simple wrapper for using the pextract python script :)
declare function pfile:pextract-cmd(
  $pextract-py as xs:string, 
  $infile as xs:string, 
  $outfile as xs:string,
  $sys-encoding as xs:string?)
{
  let $encoding := if($sys-encoding)
                   then($sys-encoding)
                   else("latin1")
  let $infile-contents := lazy:cache(file:read-text($infile, "UTF-8"))
  let $outfile-contents :=
    proc:system("python", ($pextract-py), map { "input": $infile-contents, "encoding": $encoding } )
  return file:write-text($outfile, $outfile-contents)
};
