#!/usr/bin/env bash


function removeRevision(){
    local file

    (
        cd "$bundle" || return
        [[ -d manifests ]] && rm -rf manifests
        [[ -d resources ]] && rm -rf resources
        [[ -f "${item}.xml" ]] && rm "${item}.xml"
        if [[ -d policies ]]; then
            (
                cd policies
                for file in FC-*.xml; do [[ -f "$file" ]] && rm "$file"; done
            )
        fi
    )
}


function copyRevision(){
    local service
    local folder="null"
    declare -a services=(
    -client-portal-
    -backoffice-
    -tef-embarcado-
    motor-pix-v
    conciliation-v
    ctf-cloud-v
    )
    declare -A folders=(
    ["${services[0]}"]="common"
    ["${services[1]}"]="common"
    ["${services[2]}"]="common"
    ["${services[3]}"]="common"
    ["${services[4]}"]="common"
    ["${services[5]}"]="ctf-cloud"
    )

    for service in "${services[@]}"; do
        [[ "$item" == *"$service"* ]] && folder="${folders["$service"]}"
    done
    if [[ -d "$ROOT_DIR/transformation/$folder" ]]; then
        (
            cd "$ROOT_DIR/transformation/$folder"
            cp policies/*.xml "$upload_dir/$item/$bundle/policies/"
            cp -r resources "$upload_dir/$item/$bundle/"
            cp main.xml "$upload_dir/$item/$bundle/"
            7z x proxy.zip >/dev/null
            tr "\n" "|" < "$upload_dir/$item/$bundle/proxies/default.xml" | grep -o '<Flows>.*</Flows>' | sed 's/\(<Flows>\|<\/Flows>\)//g;s/|/\n/g' >"$TEMPO"
            cat proxy.xml | sed $'/<!--#CHANGE1-->/{e cat $TEMPO\n}' >default1.xml
            tr "\n" "|" < "$upload_dir/$item/$bundle/proxies/default.xml" | grep -o '</PostClientFlow>.*</ProxyEndpoint>' | sed 's/\(<\/PostClientFlow>\|<\/ProxyEndpoint>\)//g;s/|/\n/g' >"$TEMPO"
            cat default1.xml | sed $'/<!--#CHANGE2-->/{e cat $TEMPO\n}' >default2.xml
            sed -i '/<!--#CHANGE1-->/d;/<!--#CHANGE2-->/d' default2.xml
            grep "\S" default2.xml >default.xml
            cp default.xml "$upload_dir/$item/$bundle/proxies/default.xml"
            rm default*.xml
            rm proxy.xml
        )
    fi
}


function removeTransformation(){
    [[ -z "$planet" ]] && planet="dev"
    cp "$item.json" "$planet.json"
    sed -i '/createdAt/d;/createdBy/d' "$planet.json"
    sed -i '/lastModifiedAt/d;/lastModifiedBy/d' "$planet.json"
    perl -0pe 's/,(\s\})/$1/' "$planet.json" > auxiliar.json
    mv auxiliar.json "$planet.json"
}

function apis_transform(){
    local bundle
    local file
    local planet
    local item
    local upload_dir
    declare -A data=(
    ["hml","target"]='s/-des./-hti./g;s/-dev./-hml./g'
    ["hml","AM-CORS.xml"]='s/-dev./-hti./g'
    ["hml","ML-LogELK.xml"]='s/-dev./-hml./g'
    ["prd","target"]='s/-hti./-prd./g;s/-hml./-prd./g'
    ["prd","AM-CORS.xml"]='s/-hti././g'
    ["prd","ML-LogELK.xml"]='s/-hml././g'
    )

    upload_dir="$ROOT_DIR/uploads/$CONTEXT/$ORG"
    for item in $list; do
        [[ "$item" != *"$object"* ]] && continue
        if [[ -d "$upload_dir/$item" ]]; then
        cp -r "backup/$DATE/$ORG/$item" "$upload_dir"
            bundle="apiproxy"
            (
                cd "$upload_dir/$item" || return
                7z x "${item}_rev*.zip" >/dev/null
                removeRevision
                copyRevision
                7z a -r dev.zip "$bundle" >/dev/null
                removeTransformation
                for planet in "hml" "prd"; do
                    removeTransformation
                    if [[ -d "$bundle/targets" ]]; then
                        (
                            cd "$bundle/targets"
                            for file in *.xml; do
                                [[ -f "$file" ]] && sed -i "${data["$planet","target"]}" "$file"
                            done
                        )
                    fi
                    if [[ -d "$bundle/policies" ]]; then
                        (
                            cd "$bundle/policies"
                            for file in "AM-CORS.xml" "ML-LogELK.xml"; do
                                [[ -f "$file" ]] && sed -i "${data["$planet","$file"]}" "$file"
                            done
                        )
                    fi
                    7z a -r "${planet}.zip" "$bundle" >/dev/null
                done
                rm -rf "$bundle"
                sed -i 's/"dev"/"hti"/' hml.json
                sed -i 's/"dev"/"prd"/' prd.json
            )
        fi
    done
}


function transform(){
    local item
    local planet
    local object

    object="$obj"
    if [[ "$CONTEXT" == "apis" ]]; then
        apis_transform
    else
        for item in $list; do
            cp -r "backup/$DATE/$ORG/$item" "$ROOT_DIR/uploads/$CONTEXT/$ORG"
            if [[ -d "$ROOT_DIR/uploads/$CONTEXT/$ORG/$item" ]]; then
                (
                cd "$ROOT_DIR/uploads/$CONTEXT/$ORG/$item"
                for planet in "dev" "hml" "prd"; do
                    removeTransformation
                done
                sed -i 's/"dev"/"hti"/' hml.json
                sed -i 's/"dev"/"prd"/' prd.json
                )
            fi
        done
    fi
}


function update(){
    [[ -z "$api" ]] && api="$1"
    curl --request POST "$URL/v1/organizations/auttar/apis/$api/revisions/2/policies/AM-CORS" \
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


function delete(){
    curl --request DELETE "$URL/v1/organizations/auttar/companies/CTF-Cloud/apps/CTF-Cloud/keys/HxL3DupN6UaOfaFOqGEi7gN5Ejgq72cT" \
    --user "$USERNAME:$PASSWORD"
}
