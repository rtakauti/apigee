#!/usr/bin/env bash

function transform(){
    [[ "$CONTEXT" == "apis" ]] && transformApi
    [[ "$CONTEXT" == "sharedflows" ]] && transformSharedflow
}

function copyTransformation(){
    local object
    local folder

    object="client-portal"; [[ "$element" == *"$object"* ]] && folder="$object"
    (
        cd "$ROOT_DIR/transformation/$folder" || return
        cp policies/*.xml "$upload_dir/$element/$bundle/policies/"
        cp -r resources "$upload_dir/$element/$bundle/"
        cp main.xml "$upload_dir/$element/$bundle/"
        7z x proxy.zip >/dev/null
        tr "\n" "|" < "$upload_dir/$element/$bundle/proxies/default.xml" | grep -o '<Flows>.*</Flows>' | sed 's/\(<Flows>\|<\/Flows>\)//g;s/|/\n/g' >"$TEMPO"
        cat proxy.xml | sed $'/<!--#CHANGE1-->/{e cat $TEMPO\n}' >default1.xml
        tr "\n" "|" < "$upload_dir/$element/$bundle/proxies/default.xml" | grep -o '</PostClientFlow>.*</ProxyEndpoint>' | sed 's/\(<\/PostClientFlow>\|<\/ProxyEndpoint>\)//g;s/|/\n/g' >"$TEMPO"
        cat default1.xml | sed $'/<!--#CHANGE2-->/{e cat $TEMPO\n}' >default.xml
        sed -i '/<!--#CHANGE1-->/d;/<!--#CHANGE2-->/d' default.xml
        cp default.xml "$upload_dir/$element/$bundle/proxies/default.xml"
        rm default*.xml
        rm proxy.xml
    )
}


function transformApi(){
    local bundle
    local file
    local planet
    declare -A data=(
    ["hml","target"]='s/-des./-hti./g;s/-dev./-hml./g'
    ["hml","CORS"]='s/-dev./-hti./g'
    ["hml","LogELK"]='s/-dev./-hml./g'
    ["prd","target"]='s/-hti./-prd./g;s/-hml./-prd./g'
    ["prd","CORS"]='s/-hti././g'
    ["prd","LogELK"]='s/-hml././g'
    )

    bundle="apiproxy"
    (
        cd "$upload_dir/$element" || return
        7z x "${element}_rev${revision}_$(TZ=GMT date +"%Y_%m_%d").zip" >/dev/null
        (
            cd "$bundle" || return
            rm -rf manifests
            rm "${element}.xml"
            rm -rf resources
            (
                cd policies || return
                rm FC-*.xml
            )
        )

        copyTransformation

        7z a -r dev.zip "$bundle" >/dev/null

        for planet in "hml" "prd"; do
            (
                cd "$bundle/targets" || return
                for file in *.xml; do
                    [[ -f "$file" ]] && sed -i "${data["$planet","target"]}" "$file"
                done
            )

            (
                cd "$bundle/policies" || return
                file="AM-CORS.xml"; [[ -f "$file" ]] && sed -i "${data["$planet","CORS"]}" "$file"
                file="ML-LogELK.xml"; [[ -f "$file" ]] && sed -i "${data["$planet","LogELK"]}" "$file"
            )

            7z a -r "${planet}.zip" "$bundle" >/dev/null
        done

        rm -rf "$bundle"
    )
}


function transformSharedflow(){
    local bundle

    bundle="sharedflowbundle"
    (
        transformMain

        (
            cd "$bundle/policies" || return
            [[ -f "ML-LogELK.xml" ]] && sed -i 's/-dev./-hml./g' "ML-LogELK.xml"
        )

        7z a -r hml.zip "$bundle" >/dev/null

        (
            cd "$bundle/policies" || return
            [[ -f "ML-LogELK.xml" ]] && sed -i 's/-hml././g' "ML-LogELK.xml"
        )

        7z a -r prd.zip "$bundle" >/dev/null
        rm -rf "$bundle"
    )
}

function update(){

    if [[ -z "$api" ]] ; then
        api="$1"
    fi

    curl --include --request POST "$URL/v1/organizations/auttar/apis/$api/revisions/2/policies/AM-CORS" \
    --user "$USERNAME:$PASSWORD" \
    --header 'Content-Type: application/xml' \
    --data-raw '<AssignMessage async="false" continueOnError="false" enabled="true" name="AM-CORS">
    <DisplayName>AM-CORS</DisplayName>
    <FaultRules/>
    <Properties/>
    <Set>
        <Headers>
            <Header name="Access-Control-Allow-Origin">{request.header.origin}</Header>
            <Header name="Access-Control-Allow-Headers">*</Header>
            <Header name="Access-Control-Max-Age">3628800</Header>
            <Header name="Access-Control-Allow-Methods">GET</Header>
        </Headers>
    </Set>
    <IgnoreUnresolvedVariables>true</IgnoreUnresolvedVariables>
    <AssignTo createNew="false" transport="http" type="response"/>
</AssignMessage>'
}

function company(){

    if [[ -z "$api" ]] ; then
        api="$1"
    fi

    curl --include --request POST "$URL/v1/organizations/auttar/companies" \
    --user "$USERNAME:$PASSWORD" \
    --header 'Content-Type: application/json' \
    --data-raw '{
        "name": "CTF-Cloud"
    }'
}

function app(){
    curl --location --request POST  "$URL/v1/organizations/auttar/companies/CTF-Cloud/apps" \
    --user "$USERNAME:$PASSWORD" \
    --header 'Content-Type: application/json' \
    --data-raw '{
        "apiProducts":["CTF-Cloud"],
        "name": "CTF-Cloud"
        }'
}

function delete(){
curl --location --request DELETE "$URL/v1/organizations/auttar/companies/CTF-Cloud/apps/CTF-Cloud/keys/HxL3DupN6UaOfaFOqGEi7gN5Ejgq72cT" \
        --user "$USERNAME:$PASSWORD"
}

function import(){
    curl --location --request POST "$URL/v1/organizations/auttar/companies/CTF-Cloud/apps/CTF-Cloud/keys/create" \
        --user "$USERNAME:$PASSWORD" \
        --header 'Content-Type: application/json' \
        --data-raw '{
            "consumerKey":"'"$SUBSCRIPTION_KEY"'",
            "consumerSecret":"'"$COMPANY"'"
         }'
}