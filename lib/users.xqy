xquery version "1.0-ml";

(:~
 : Licensed under the Apache License, Version 2.0 (the "License");
 : you may not use this file except in compliance with the License.
 : You may obtain a copy of the License at
 :
 :     http://www.apache.org/licenses/LICENSE-2.0
 :
 : Unless required by applicable law or agreed to in writing, software
 : distributed under the License is distributed on an "AS IS" BASIS,
 : WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 : See the License for the specific language governing permissions and
 : limitations under the License.
 :)

module namespace users = "users";
import module namespace cookies = "http://parthcomp.com/cookies" at "cookies.xqy";
import module namespace srv="http://marklogic.com/rundmc/server-urls" at "/controller/server-urls.xqy";
import module namespace util="http://markmail.org/util" at "/lib/util.xqy";

declare default function namespace "http://www.w3.org/2005/xpath-functions";

declare namespace em="URN:ietf:params:email-xml:";

declare function users:emailInUse($email as xs:string) as xs:boolean
{
    exists(/person[email eq $email])
};

declare function users:getUserByEmail($email as xs:string) as element(*)?
{
    /person[email eq $email]
};

declare function users:getUserByID($id as xs:string) as element(*)?
{
    /person[id eq $id]
};


declare function users:startSession($user as element(*)) as empty-sequence()
{
    let $sessionID := string(xdmp:random())
    let $name := $user/name
    let $id := $user/id/string()
    let $uri := concat("/private/people/", $id, "/session.xml")
    let $doc := <session>
        <id>{$id}</id>
        <session-id>{$sessionID}</session-id>
    </session>
    let $_ := xdmp:document-insert($uri, $doc) 

    return 
        cookies:add-cookie("RUNDMC-SESSION", $sessionID, current-dateTime() + xs:dayTimeDuration("P60D"), 
            $srv:cookie-domain, "/", false())
};

declare function users:endSession() as empty-sequence()
{

    (: todo remove session id from /person ? :) 
    cookies:delete-cookie("RUNDMC-SESSION", $srv:cookie-domain, "/")
};

declare function users:getCurrentUserName()
    as xs:string?
{
    let $n := users:getCurrentUser()/name/string()
    return if ($n eq "") then () else $n
};

declare function users:authViaParams() as xs:boolean
{
    let $email := xdmp:get-request-field("email")
    let $user := /person[email eq $email]
    let $hash := xdmp:crypt(xdmp:get-request-field("pass"), $email)
    return ($user and ($user/password/string() = $hash))
    
};

declare function users:createOrUpdateUser($name, $email, $password, $others)
{
    let $user := /person[email eq $email]
    let $hash := xdmp:crypt($password, $email)

    return
    if ($user) then
        if ($user/password = ("", $hash)) then
            users:updateUserWithPassword($user, $name, $password, $others)
        else
            "Email address in already registered"
    else
        users:createUser($name, $email, $password, $others)
};

declare function users:createUser($name, $email, $pass, $others)
as element(*)? 
{
    let $id := xdmp:random()
    let $uri := concat("/private/people/", $id, ".xml")
    let $hash := xdmp:crypt($pass, $email)
    let $doc := 
        <person>
            <id>{$id}</id>
            <email>{$email}</email>
            <name>{$name}</name>
            <password>{$hash}</password>
            <created>{fn:current-dateTime()}</created>
            {$others}
        </person>

    let $_ := xdmp:document-insert($uri, $doc)
    let $list := $others[local-name() = 'list']
    let $_ := if ($list eq "on") then users:registerForMailingList($email, $pass) else ()
    let $_ := users:logNewUser($doc)

    return $doc
};

declare function users:createUserAndRecordLicense($type, $name, $email, $pass, $list, $others, $meta)
as element(*)? 
{
    let $id := xdmp:random()
    let $uri := concat("/private/people/", $id, ".xml")
    let $hash := xdmp:crypt($pass, $email)
    let $now := fn:current-dateTime()
    let $co := $others/*:organization

    let $doc := 
        <person>
            <id>{$id}</id>
            <email>{$email}</email>
            <name>{$name}</name>
            <password>{$hash}</password>
            <created>{$now}</created>
            {$others}
            <license>
                <type>{$type}</type>
                <company>{$co}</company>
                <date>{$now}</date>
                <licensee>{$name}</licensee>
                {$meta}
            </license>
        </person>

    let $_ := xdmp:document-insert($uri, $doc)
    let $_ := if ($list eq "on") then users:registerForMailingList($email, $pass) else ()
    let $_ := users:logNewUser($doc)
    let $lead := users:mkto-sync-lead($email, $doc, "License Request")

    return $doc
};

declare function users:recordLicense($email, $company, $license-metadata, $type)
{
    let $user := users:getUserByEmail($email)
    let $uri := base-uri($user)
    let $name := $user/name/string()
    let $doc := <person>
        { for $field in $user/* where not($field/local-name() = ('organization')) return $field }
            <organization>{$company}</organization>
            <license>
                <type>{$type}</type>
                <company>{$company}</company>
                <date>{fn:current-dateTime()}</date>
                <licensee>{$name}</licensee>
                {$license-metadata}
            </license>
        </person>

    let $_ := xdmp:document-insert($uri, $doc)
    let $_ := users:mkto-associate-lead($email, $doc)
    return  $doc
};

declare function users:recordAcademicLicense($email, $school, $yog, $license-metadata)
{
    let $user := users:getUserByEmail($email)
    let $uri := base-uri($user)
    let $name := $user/name/string()
    let $doc := <person>
        { for $field in $user/* where not($field/local-name() = ('school', 'yog')) return $field }
            <school>{$school}</school>
            <yog>{$yog}</yog>
            <license>
                <type>academic</type>
                <school>{$school}</school>
                <yog>{$yog}</yog>
                <date>{fn:current-dateTime()}</date>
                <licensee>{$name}</licensee>
                {$license-metadata}
            </license>
        </person>

    let $_ := xdmp:document-insert($uri, $doc)
    let $_ := users:mkto-associate-lead($email, $doc)
    return  $doc
};


declare function users:updateUserWithPassword($user, $name, $password, $others) 
as element(*)? 
{
    let $uri := base-uri($user)
    let $email := $user/email/string()
    let $hash := xdmp:crypt($password, $email)
    let $othernames := for $i in $others return local-name($i)
    let $doc := 
        <person>
        { for $field in $user/* where (
            not($field/local-name() = ('name', 'password')) and 
            not($field/local-name() = $othernames))  
          return $field }
            <name>{$name}</name>
            <password>{$hash}</password>
            {$others}
        </person>

    let $_ := xdmp:document-insert($uri, $doc)

    let $list := $others[local-name() = 'list']

    let $_ := if ($list eq "on") then 
        users:registerForMailingList($email, $password)
    else    
        ()

    return  $doc
};

declare function users:registerForMailingList($email, $pass) 
{
    let $user := /person[email eq $email]
    let $uri := concat("http://developer.marklogic.com/mailman/subscribe/general", "")

    let $payload :=
        concat(
            "email=", xdmp:url-encode($email),
            "&amp;fullname=", xdmp:url-encode($user/name/string()),
            "&amp;pw=", xdmp:url-encode($pass),
            "&amp;pw-conf=", xdmp:url-encode($pass)
        )

    return
        xdmp:http-post($uri, <options xmlns="xdmp:http">
            <headers>
                <content-type>application/x-www-form-urlencoded</content-type>
            </headers>
            <data>{ $payload }</data>
        </options>)
        

};

declare function users:logNewUser($user) 
{
    let $_ := xdmp:log(concat("Created user ", $user/id))

    let $hostname := xdmp:hostname()

    let $staging := if ($hostname = "stage-developer.marklogic.com") then "Staging " else ""

    let $address := 
        if ($hostname = ("developer.marklogic.com", "stage-developer.marklogic.com", "dmc-stage.marklogic.com")) then
            "dmc-admin@marklogic.com"
        else if ($hostname = ("wlan31-12-236.marklogic.com", "dhcp141.marklogic.com")) then
            "eric.bloch@marklogic.com"
        else
            ()

    let $_ := if ($address) then
        util:sendEmail(

            "RunDMC Signup",
            $address,
            false(),
            "RunDMC Admin",
            $address,
            "RunDMC Admin",
            $address,
            concat($staging, "Signed up user ", $user/email/string()), 
            <em:content>
            {concat("
Username: ", $user/name/string(), "
Email: ", $user/email/string(), "
ID: ", $user/id/string(), "
Organization: ", $user/organization/string(), "
Industry: ", $user/industry/string(), "
Country: ", $user/country/string(), "
")
            }
            </em:content>
        )
    else
        ()

    return ()
};

declare function users:warn-denied-person($user, $country, $country-code)
{
    let $_ := xdmp:log(concat("DENIED NAME", $user/name/string(), " from ", $country, " (", $country-code, " )")) 

    let $hostname := xdmp:hostname()

    let $staging := if ($hostname = "stage-developer.marklogic.com") then "Staging " else ""

    let $address := 
        if ($hostname = ("developer.marklogic.com", "stage-developer.marklogic.com", "dmc-stage.marklogic.com")) then
            "dmc-admin@marklogic.com"
        else if ($hostname = ("wlan31-12-236.marklogic.com", "dhcp141.marklogic.com")) then
            "eric.bloch@marklogic.com"
        else
            ()

    let $_ := if ($address) then
        util:sendEmail(

            "RunDMC DENIED PERSON",
            $address,
            false(),
            "RunDMC Admin",
            $address,
            "RunDMC Admin",
            $address,
            concat($staging, "DENIED user ", $user/email/string()), 
            <em:content>
            {concat("
Username: ", $user/name/string(), "
Email: ", $user/email/string(), "
ID: ", $user/id/string(), "
Organization: ", $user/organization/string(), "
Industry: ", $user/industry/string(), "
Country: ", $user/country/string(), "
")
            }
            </em:content>
        )
    else
        ()

    return ()
};

declare function users:checkCreds($email as xs:string, $password as xs:string) as element(*)?
{
    let $user := /person[email eq $email]
    return
    if ($user/password eq xdmp:crypt($password, $email)) then
        $user
    else
        ()
};

declare function users:signupsEnabled()
    as xs:boolean
{
    true() (: not(empty(cookies:get-cookie("RUNDMC-SIGNUPS"))) :)
};

declare function users:cornifyEnabled()
    as xs:boolean
{
    not(empty(cookies:get-cookie("RUNDMC-CORN")))
};

declare function users:getCurrentUser() as element(*)?
{
    let $session := cookies:get-cookie("RUNDMC-SESSION")[1]
    let $id := /session[session-id eq $session]/id/string() 
    return /person[id eq $id]
};

declare function users:getResetToken($email as xs:string) as xs:string
{
    let $user := /person[email eq $email]
    let $now := fn:string(fn:current-time())
    let $token := xdmp:crypt($email, $now)
    let $doc := 
        <person>
            { for $field in $user/* where not($field/local-name() = ('reset-token')) return $field }
            <reset-token>{$token}</reset-token>
        </person>
    let $_ := xdmp:document-insert(base-uri($user), $doc)

    return $token
};

declare function users:setPassword($user as element(*)?, $password as xs:string)
{
    let $email := $user/email/string()
    let $hash := xdmp:crypt($password, $email)

    let $doc := 
        <person>
            { for $field in $user/* where not($field/local-name() = ('reset-token', 'password')) return $field }
            <password>{$hash}</password>
        </person>

    return xdmp:document-insert(base-uri($user), $doc)
};

(: save params into the user, leaving along fields not specified in the params :)
declare function users:saveProfile($user as element(*), $params as element(*)*) as element(*)
{
    (: todo: cheap secure by only storing first 10? :) 

    (: trim params from input to only the ones we support for now, todo: generate from/share with profile-form in tag-lib :)
    let $fields := ('organization', 'name', 'url', 'picture', 'location', 'country', 'twitter', 'school', 'yog',
                    'country', 'industry', 'phone' )
    let $params := for $p in $params where $p/@name = $fields return $p

    let $doc := <person>
        { for $field in $user/* where not($field/local-name() = ($params/@name)) return $field }
        { for $field in $params return element {$field/@name} {$field/string()} }
    </person>

    let $_ := xdmp:document-insert(base-uri($user), $doc)
    let $_ := xdmp:log(concat("Updated profile for ", $user/email, " : ", xdmp:quote($doc)))

    return $doc
};

(: save params into the user, leaving along fields not specified in the params :)
declare function users:validateParams($user as element(*), $params as element(*)*) as xs:string
{
    (: TODO :)
    "ok"
};

(: associate the given email (and current mkto_trk cookie) with a lead in marketo :) 
declare function users:mkto-associate-lead($email as xs:string, $doc)
{
    let $cookie := cookies:get-cookie('_mkto_trk')[1]

    return xdmp:spawn("marketo-associate-lead.xqy", (
        xs:QName("email"), $email, 
        xs:QName("cookie"), if ($cookie) then $cookie else "",
        xs:QName("doc"), $doc 
    ) )
};

(: sync the given user with a lead in marketo :) 
declare function users:mkto-sync-lead($email as xs:string, $user, $source)
{
    let $cookie := cookies:get-cookie('_mkto_trk')[1]

    return xdmp:spawn("marketo-sync-lead.xqy", (
        xs:QName("email"), $email, 
        xs:QName("user"), $user,
        xs:QName("cookie"), if ($cookie) then $cookie else "",
        xs:QName("source"), $source
    ) )
};

(: record a download :)
declare function users:record-download-for-current-user($path as xs:string)
{
    let $user := users:getCurrentUser()
    
    return if ($user) then
        xdmp:node-insert-child($user,
            <download>
                <path>{$path}</path>
                <date>{fn:current-dateTime()}</date>
                <client>{xdmp:get-request-client-address()}</client>
                <fwded-for>{xdmp:get-request-header("X-Forwarded-For")}</fwded-for>
            </download>
        )
    else 
        ()
};

declare function users:denied() as xs:boolean
{
    let $user := users:getCurrentUser()

    return
    if ($user) then
        let $name := $user/name/string()
        let $org := $user/organization/string()
        let $country := $user/country/string()
        let $country-code := doc("/private/countries.xml")/*:select/*:option[@*:value = $country]/@*:data-code

        let $opts := ("case-insensitive", "diacritic-insensitive", "whitespace-insensitive", "punctuation-insensitive")
        (: match on name OR organization :)
        let $person := cts:search(
            /denied-persons/person,
            cts:or-query(
                (cts:element-value-query(xs:QName("Name"), $name, $opts), cts:element-value-query(xs:QName("Name"), $org, $opts))
            )
        )

        return if ($person) then 
            if ($country-code = $person/Country/string()) then
                let $_ := users:warn-denied-person($user, $country, $country-code) 
                return true()
            else
                false()
        else 
            false()
    else
        false()
};
