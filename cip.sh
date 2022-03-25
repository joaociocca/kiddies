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

    now=$(date '+%FT%T.%3NZ')
    lastweek=$(date --date='-1 week' '+%FT%T.%3NZ')

    echo "Pesquisar período padrão, última semana?"
    select sn in "Sim" "Não"; do
        case $sn in
            Sim ) padrao=true; break;;
            Não ) padrao=false; break;;
        esac
    done

    if [ $padrao == "true" ]; then
        start=$lastweek
        end=$now
    else
        cat << EOF

Pesquisar por qual período?

1) 3 últimos meses
2) 6 últimos meses
3) 12 últimos meses (1 ano)
EOF
#4) 18 últimos meses (1 ano e meio)
#5) 24 últimos meses (2 anos)
#6) Personalizar pesquisa
        printf "\nInforme a opção desejada: "
        IFS= read -r periodo
        case $periodo in
            1 ) start=$(date --date='-3 months' '+%FT%T.%3NZ'); end=$now;;
            2 ) start=$(date --date='-6 months' '+%FT%T.%3NZ'); end=$now;;
            3 ) start=$(date --date='-12 months' '+%FT%T.%3NZ'); end=$now;;
            # 4 ) start=$(date --date='-18 months' '+%FT%T.%3NZ'); end=$now;;
            # 5 ) start=$(date --date='-24 months' '+%FT%T.%3NZ'); end=$now;;
            # 6 ) echo "a ser implementado...";;
        esac
    fi

    # LISTA SISTEMAS

    printf "\nExecutar pesquisa completa (padrão) de sistemas e listas?\n"
    select sn in "Sim" "Não"; do
        case $sn in
            Sim ) completa=true; break;;
            Não ) completa=false; break;;
        esac
    done

    opcoesSistemas="SITRAF SLC SILOC SCC CTC C3%20REGISTRADORA PCR CHEQUE%20LEGAL PCPS STD MCB PCPO CIP SRCC SECHUB"
    opcoesLista="Monitoramento QA SAP SistemasIMF TI AssessoriaExecutiva Compliance Comunicacao DadosEstrategicos Financeiro Juridico Negocios ProdutosIMF"
    if [ ! "$completa" == true ]; then
        printf '\nOpções disponíveis de listas: %s' "$opcoesLista"
        printf '\nInforme as listas a serem pesquisadas, separando por espaço: '
        read -r opcoesLista
        printf '\nOpções disponíveis de sistemas: %s' "$opcoesSistemas"
        printf '\nInforme os sistemas a serem pesquisados, separando por espaço: '
        read -r opcoesSistemas
        
    fi

    echo ""
    countLista=$(wc -w <<< "$opcoesLista")
    countSistemas=$(wc -w <<< "$opcoesSistemas")
    (( total="$countLista"*"$countSistemas" ))

    iSistemaLista=1
    count=1
    for sistema in $opcoesSistemas; do
        for lista in $opcoesLista ; do
            perc="$(printf %.2f%%"\n" "$((10**3 * 100 * "$iSistemaLista" / "$total"))e-3" | tr '.' ',')"
            # echo "Verificando sistema $sistema, lista $lista"
            (( spc=3-"$count" ))
            v=$(printf "%-${count}s" ".")
            s=$(printf "%-${spc}s" " ")
            echo -ne "Efetuando consulta${v// /.}${s// / }\t$perc\r"
            sleep 1
            if [ "$count" -eq 3 ]; then count=0; fi
            (( count+=1 ))

            filter="OData__ModerationStatus eq 0"
            filter+=" and (LocalPublicacao eq 'WebSite' or LocalPublicacao eq 'Ambos')"
            filter+=" and DataPublicacao gt '$start'"
            filter+=" and DataPublicacao lt '$end'"
            filter+=" and Ativo eq 1"
            filter+=" and Solucao eq '$sistema'"
            filter=$(jq -rn --arg x "$filter" '$x|@uri' | sed "s#'#%27#g")

            path="_api/web/lists/$lista/items?\$"
            path+="select=FileRef&\$"
            path+="filter=${filter}"
            path+="&\$orderby=Created%20desc"
            path+="&\$top=5000"

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

            echo "$json" | jq | sed -n -r 's#(\s+)?"FileRef": "(.+Atualização( dos?)? Certificados?.+\.pdf)",?#\2#p' \
            | cat >> arquivos.txt
            #| tee -a arquivos.txt
            (( iSistemaLista+=1 ))
        done
    done

    cat << EOF
===============================

Consultas finalizadas, listando URLs para download.

===============================
EOF
    if [ -s arquivos.txt ]; then
        while read -u 9 -r line; do
            echo "$line" | sed -n -r 's#\/[^\/]+\/(.+)#\1#p'
            link=$(jq -rn --arg x "$line" '$x|@uri' | sed "s#%2F#/#g")
            printf "\t >> https://www.cip-bancos.org.br%s\n\n" "${link}"
        done 9< arquivos.txt
    else
        printf "\n\tNão foram encontrados arquivos de atualização de certificado no período, lista(s) e/ou sistema(s) selecionado(s).\n\n"
    fi
    rm -rf arquivos.txt sistemas.txt 2>/dev/null
fi