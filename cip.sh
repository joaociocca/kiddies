#!/usr/bin/env bash

if ! command -v jq &>/dev/null; then
    echo "JQ não encontrado. Instalar?"
    select sn in "Sim" "Não"; do
        case $sn in
            Não ) echo "JQ necessário para executar script."; break;;
            Sim ) sudo apt-get install jq xq -y; go=true; break;;
        esac
    done
fi

if [ -z $go ]; then
    if [ -f ./arquivos.txt ]; then
        rm ./arquivos.txt
    fi

    # filter="OData__ModerationStatus%20eq%200%20and%20(LocalPublicacao%20eq%20%27WebSite%27%20or%20LocalPublicacao%20eq%20%27Ambos%27)%20and%20DataPublicacao%20lt%20%272022-03-24T12%3A32%3A15.423Z%27%20and%20Ativo%20eq%201and%20(FileRef%20contains%20%22Atualiza%C3%A7%C3%A3o%20do%20Certificado%22%20or%20FileRef%20contains%20%22Atualiza%C3%A7%C3%A3o%20dos%20Certificados%22)"
    # # fim do filtro tinha: "%20and%20Solucao%20eq%20%27SITRAF%27"
    # path="_api/web/lists/Monitoramento/items?\$expand=Tipo_x0020_de_x0020_Documento&\$select=Title,FileRef,Created,Solucao,Tipo_x0020_de_x0020_Documento/Id,Tipo_x0020_de_x0020_Documento/Title,FileSizeDisplay,Modified,LocalPublicacao,DataPublicacao&\$filter=${filter}&\$orderby=Created%20desc&\$top=5000"

    # LISTA SISTEMAS

    curl -s "https://www.cip-bancos.org.br/_api/web/lists/SugestoesList/items?\$select=Title,Id&\$filter=ID%20ge%200%20and%20ID%20lt%204999&\$top=5000" \
        -H 'authority: www.cip-bancos.org.br' \
        -H 'pragma: no-cache' \
        -H 'cache-control: no-cache' \
        -H 'sec-ch-ua: " Not A;Brand";v="99", "Chromium";v="99", "Google Chrome";v="99"' \
        -H 'accept: application/json; odata=verbose' \
        -H 'dnt: 1' \
        -H 'x-requested-with: XMLHttpRequest' \
        -H 'sec-ch-ua-mobile: ?0' \
        -H 'user-agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/99.0.4844.74 Safari/537.36' \
        -H 'sec-ch-ua-platform: "Windows"' \
        -H 'sec-fetch-site: same-origin' \
        -H 'sec-fetch-mode: cors' \
        -H 'sec-fetch-dest: empty' \
        -H 'referer: https://www.cip-bancos.org.br/SitePages/Documentos.aspx' \
        -H 'accept-language: pt-BR,pt;q=0.9,en;q=0.8,en-GB;q=0.7,en-US;q=0.6' \
        -H $'cookie: WSS_FullScreenMode=false; F5SESSIONID=\u0021BBlY1vnBVclOnRg7B3w78pao9MDL2OVG/OM5X9GNgjUu8Uh04qPQotTzmLaPjmRlm3YoUo1+kxKcZQ==; TS01d42117=017828800020e18b27159d42d196c925d8c7b2a2b8c3186ee4530899831123cfc476ceb6f47244be1d9c91f3f8167fdceef0af5d8b; AWSALB=G4zKes5V8b7MvMBrN4obFQlRpYVAy2pTmHerf9yLKnIWLxBvYbTK0m0D9H/s4HYJNpEskACXMLqGF+Vj1pNMZ9caeSL6/WZbxotXyHR76oQUfRCCcs/0Rd4cyun+; AWSALBCORS=G4zKes5V8b7MvMBrN4obFQlRpYVAy2pTmHerf9yLKnIWLxBvYbTK0m0D9H/s4HYJNpEskACXMLqGF+Vj1pNMZ9caeSL6/WZbxotXyHR76oQUfRCCcs/0Rd4cyun+' \
        -H 'sec-gpc: 1' \
        --compressed | jq | grep -i title | cut -d'"' -f4 | sort > sistemas.txt

    while read -u 9 -r sistema; do
        for lista in AssessoriaExecutiva Compliance Comunicacao DadosEstrategicos Financeiro Juridico Monitoramento Negocios ProdutosIMF QA SAP SistemasIMF TI; do
            echo "Verificando sistema $sistema, lista $lista"

            filter="OData__ModerationStatus eq 0"
            filter+=" and (LocalPublicacao eq 'WebSite' or LocalPublicacao eq 'Ambos')"
            filter+=" and DataPublicacao lt '2022-03-24T12:32:15.423Z'"
            # filter+=" and DataPublicacao gt '2021-12-31T23:59:59.423Z'"
            filter+=" and Ativo eq 1"
            # filter+="(FileRef contains 'Atualização do Certificado' or FileRef contains 'Atualização dos Certificados')"
            # filter+=" and Solucao eq 'SITRAF'"
            filter+=" and Solucao eq '$sistema'"
            filter=$(jq -rn --arg x "$filter" '$x|@uri' | sed "s#'#%27#g")

            path="_api/web/lists/$lista/items?\$"
            path+="select=FileRef&\$"
            path+="filter=${filter}"
            path+="&\$orderby=Created%20desc"
            path+="&\$top=5000"

        # select=FileRef&$filter=
        #     OData__ModerationStatus eq 0 and (LocalPublicacao eq 'WebSite' or LocalPublicacao eq 'Ambos') and DataPublicacao lt '2022-03-24T14:56:55.240Z' and Ativo eq 1 and Solucao eq 'SCC'
        #     &$orderby=Created%20desc&$top=5000

            url="https://www.cip-bancos.org.br/${path}"

            json=$(curl -s "$url" \
            -H 'authority: www.cip-bancos.org.br' \
            -H 'pragma: no-cache' \
            -H 'cache-control: no-cache' \
            -H 'sec-ch-ua: " Not A;Brand";v="99", "Chromium";v="99", "Google Chrome";v="99"' \
            -H 'accept: application/json; odata=verbose' \
            -H 'dnt: 1' \
            -H 'x-requested-with: XMLHttpRequest' \
            -H 'sec-ch-ua-mobile: ?0' \
            -H 'user-agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/99.0.4844.74 Safari/537.36' \
            -H 'sec-ch-ua-platform: "Windows"' \
            -H 'sec-fetch-site: same-origin' \
            -H 'sec-fetch-mode: cors' \
            -H 'sec-fetch-dest: empty' \
            -H 'referer: https://www.cip-bancos.org.br/SitePages/Documentos.aspx' \
            -H 'accept-language: pt-BR,pt;q=0.9,en;q=0.8,en-GB;q=0.7,en-US;q=0.6' \
            -H $'cookie: WSS_FullScreenMode=false; F5SESSIONID=\u0021BBlY1vnBVclOnRg7B3w78pao9MDL2OVG/OM5X9GNgjUu8Uh04qPQotTzmLaPjmRlm3YoUo1+kxKcZQ==; TS01d42117=01782880000ce8d100eb285a9f475b786fca3c4569eb60e681da78b3becebe1e6bb6f0d49f9e2c7884327619830a6373b57e207d32; AWSALB=BOjI27I8YSUU45W6A2SGFttbv233+EW3nnMEVn7kOLmMVg265WCeWQgJgeLRwbgzqZcNi+Zc4LhpOmLS3U91tXvwLlzMLl3LK4r/kFcjjK1GL4sDn4BFajB8Z4j5; AWSALBCORS=BOjI27I8YSUU45W6A2SGFttbv233+EW3nnMEVn7kOLmMVg265WCeWQgJgeLRwbgzqZcNi+Zc4LhpOmLS3U91tXvwLlzMLl3LK4r/kFcjjK1GL4sDn4BFajB8Z4j5' \
            -H 'sec-gpc: 1' \
            --compressed)
            
            # echo "$json" | jq

            echo "$json" | jq | sed -n -r 's#(\s+)?"FileRef": "(.+Atualização( dos?)? Certificados?.+\.pdf)",?#\2#p' | tee -a arquivos.txt
        done
    done 9< sistemas.txt

    cat << EOF
===========

Consultas finalizadas, listando URLs para download.

===========
EOF

    while read -u 9 -r line; do
        link=$(jq -rn --arg x "$line" '$x|@uri' | sed "s#%2F#/#g")
        echo "https://www.cip-bancos.org.br${link}"
    done 9< arquivos.txt
    rm arquivos.txt sistemas.txt
fi