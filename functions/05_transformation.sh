#!/usr/bin/env bash

function transformApi(){
    local bundle

    bundle="apiproxy"
    (
      cd "$upload_dir/$element" || return
      7z x "${element}_rev${revision}_$(TZ=GMT date +"%Y_%m_%d").zip" >/dev/null
        (
            cd "$bundle" || return
            rm -rf manifests
            if [[ -f "${element}.xml" ]]; then
                sed -i '/Basepaths/d' "${element}.xml"
                sed -i '/ConfigurationVersion/d' "${element}.xml"
                sed -i '/CreatedAt/d' "${element}.xml"
                sed -i '/CreatedBy/d' "${element}.xml"
                sed -i '/LastModifiedAt/d' "${element}.xml"
                sed -i '/LastModifiedBy/d' "${element}.xml"
                sed -i '/ManifestVersion/d' "${element}.xml"
            fi
        )

        7z a -r dev.zip "$bundle" >/dev/null

        (
            cd "$bundle/targets" || return
            for file in *.xml; do
                if [[ -f "$file" ]]; then
                    sed -i 's/-des./-hti./g' "$file"
                    sed -i 's/-dev./-hml./g' "$file"
                fi
            done
        )

        (
            cd "$bundle/policies" || return
            [[ -f "AM-CORS.xml" ]] && sed -i 's/-dev./-hti./g' "AM-CORS.xml"
        )

        7z a -r hml.zip "$bundle" >/dev/null

        (
            cd "$bundle/targets" || return
            for file in *.xml; do
                if [[ -f "$file" ]]; then
                    sed -i 's/-hti./-prd./g' "$file"
                    sed -i 's/-hml./-prd./g' "$file"
                fi
            done
        )

        (
            cd "$bundle/policies" || return
            [[ -f "AM-CORS.xml" ]] && sed -i 's/-hti././g' "AM-CORS.xml"
        )

        7z a -r prd.zip "$bundle" >/dev/null
        rm -rf "$bundle"
    )
}

function transformSharedflow(){
    local bundle

    bundle="sharedflowbundle"
    (
      cd "$upload_dir/$element" || return
      7z x "${element}_rev${revision}_$(TZ=GMT date +"%Y_%m_%d").zip" >/dev/null
        (
            cd "$bundle" || return
            rm -rf manifests
            if [[ -f "${element}.xml" ]]; then
                sed -i '/Basepaths/d' "${element}.xml"
                sed -i '/ConfigurationVersion/d' "${element}.xml"
                sed -i '/CreatedAt/d' "${element}.xml"
                sed -i '/CreatedBy/d' "${element}.xml"
                sed -i '/LastModifiedAt/d' "${element}.xml"
                sed -i '/LastModifiedBy/d' "${element}.xml"
                sed -i '/ManifestVersion/d' "${element}.xml"
            fi
        )

        7z a -r dev.zip "$bundle" >/dev/null

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