#!/usr/bin/env bash

# argumentos: extrai protocolo e domínio do primeiro parâmetro
#
# captura string até <símbolo>, ou exclui tudo após <símbolo>
# ${<variável>%<símbolo>*}
#
# para o protocolo, queremos tudo que estiver antes de : na URL
#
# por exemplo, em "https://teste.com.br" queremos "https"
# porém em "http://teste.com.br" queremos "http"
#
protocol=${1%:*}

# captura string depois de símbolo, ou exclui tudo antes de <símbolo>
# ${<variável>##*<símbolo>}
#
# para a URI (ou o domínio), queremos tudo que estiver depois da última /
#
# por exemplo, em "https://teste.com.br" queremos "teste.com.br"
# em "http://teste.com.br" também queremos "teste.com.br"
#
URI=${1##*/}

# verifica solicitação de debug no segundo parâmetro
if [[ -n "${2}" ]] && [[ "$2" == "DEBUG" ]]; then
    echo "Modo DEBUG ativo."
    debug_mode="ON"
fi

# verifica se as variáveis de protocolo e domínio foram definidas corretamente,
# ou seja, verifica se o usuário informou corretamente no parâmetro
#
# [[ -z "${<variável>}"]] identifica se a variável está vazia.
# [[ "${<variável_1>}" == "${<"variável_2>}"]] identifica se ambas variáveis tem o mesmo valor
# || é utilizado como "OR"; && é utilizado como AND
#
# a segunda verificação é feita pois caso o usuário informe apenas o domínio quando executar
# o script, tanto $protocol quanto $URI terão o mesmo valor.
#
if [[ -z "${protocol}" ]] || [[ -z "${URI}" ]] || [[ "${protocol}" == "${URI}" ]]; then
    cat <<EOF
    Informe o alvo no formato <protocolo>://<URI>
    Por exemplo, \`./webrecon.sh http://teste.com.br\`

    Para debug, informe "DEBUG" após o alvo
    Por exemplo, \`./webrecon.sh http://teste.com.br DEBUG\`
EOF
else
    # define parâmetros para ignorar na busca por chaves
    ignore_keys="srvkey|(primary |fa-(.+)?)key|key(word|hooks|board|frames|\.txt|_map)"
    # define parâmetros para ignorar arquivos por extensões
    ignore_files="gif,jpg,jpeg,bmp,psd,png,ttf,woff,eot"

    # procura pelo feroxbuster
    ferox="$(which feroxbuster)"

    # se não encontra o feroxbuster facilmente...
    if [[ -z "${ferox}" ]]; then
        # tenta encontrar o ferox por "força bruta", buscando qualquer arquivo chamado feroxbuster
        ferox="$(find / -name feroxbuster -type f -print -quit 2>/dev/null)"
        # verifica se a variável $ferox continua vazia
        if [[ -z "${ferox}" ]]; then
            cat <<EOF

        Comando "feroxbuster" não existe no sistema.
        Ferramenta disponível em: https://github.com/epi052/feroxbuster

        Instalação rápida no Linux:
    cd ~
    curl -sL https://raw.githubusercontent.com/epi052/feroxbuster/master/install-nix.sh | bash

EOF
        else
            # todos blocos com a variável $debug_mode funcionam apenas quando solicitado modo DEBUG
            if [[ "${debug_mode}" == "ON" ]]; then
                echo "Iniciando..."
            fi

            # usa `nslookup` para recuperar o IP do alvo, evitando sucessivas consultas ao DNS
            # em caso de falha, não executa o processo
            if ip_target="$(nslookup "$URI" | sed -n -r 's#Address: (.+)#\1#p')"; then
                if [[ "${debug_mode}" == "ON" ]]; then
                    echo "NSLookup result: $ip_target"
                fi

                # verifica se já foi criado anteriormente o arquivo urls-sorted
                # isso foi incluído para poder executar novamente o script sem precisar
                # passar por todas etapas novamente
                if [ ! -f urls-sorted ]; then

#######################
## NAVEGAÇÃO FORÇADA ##
#######################

                    # verifica se o sistema tem uma cópia do repositório seclists
                    seclists=$(find / -iname "seclists" -type d -print -quit 2>/dev/null)
                    if [ ! -d "${seclists}" ]; then
                        # caso não encontrado seclists, informa ao usuário onde baixar.
                        cat <<EOF

Não encontrado seclists. Favor clonar de https://github.com/danielmiessler/SecLists.

\`git clone https://github.com/danielmiessler/SecLists.git\`

EOF
                    else
                        if [[ "${debug_mode}" == "ON" ]]; then
                            echo "seclists encontrado"
                        fi

                        # identifica se já foi feita varredura forçada de diretórios, com a existência do arquivo query.json
                        if [ ! -f "query.json" ]; then
                            # Escolher o(s) dicionários a ser(em) usado(s)
                            # Definir o tamanho dos dicionários para apresentar ao usuário
                            select escolhaTamanho in Pequeno Médio Grande; do
                                tamanho=$escolhaTamanho;break;
                            done
                            case "${tamanho}" in
                                Pequeno)
                                    regexTamanho="small"
                                ;;
                                Médio)
                                    regexTamanho="medium"
                                ;;
                                Grande)
                                    regexTamanho="big|large"
                                ;;
                            esac

                            # Encontrar os dicionários do tamanho escolhido
                            find "${seclists}"/Discovery/Web-Content/ -regextype posix-extended -regex ".+(${regexTamanho}).+" -type f -exec du -hs {} \; \
                                | sed -n -r 's#^([^ ]+)\s+(.+\/)(.+)$$#\3 (\1)#p' > wordlists
                            old_IFS=$IFS
                            IFS=$'\n'
                            # Apresentar ao usuário lista dos dicionários no tamanho escolhido ao usuário
                            select escolhaWordlist in $(<wordlists);do
                                wordlist="${seclists}/Discovery/Web-Content/${escolhaWordlist% *}"; break;
                            done
                            IFS=$old_IFS

                            # Incluir dicionário "comum e português"
                            commonpt=$(find "${seclists}"/Discovery/Web-Content/common-and-portuguese.txt)
                            if [[ -n "${commonpt}" ]]; then
                                cat "${wordlist}" "${commonpt}" \
                                    | sort -u > dicionario.txt
                            else
                                cp "${wordlist}" dicionario.txt
                            fi

                            cat <<EOF > browsers
Nenhum
Android
iOS
Chrome_Windows
Firefox_Windows
Edge_Windows
Firefox_Linux
Safari_MacOS
EOF
                            # apresentar ao usuário navegadores para utilizar no parâmetro user-agent
                            select whichBrowser in $(<browsers); do
                                case "${whichBrowser}" in
                                    Android)
                                        ua="Mozilla/5.0 (Linux; Android 11) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.120 Mobile Safari/537.36" #Android
                                    break;;
                                    iOS)
                                        ua="Mozilla/5.0 (iPhone; CPU iPhone OS 14_6 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/14.1.1 Mobile/15E148 Safari/604.1" #iOS
                                    break;;
                                    Chrome_Windows)
                                        ua="Mozilla/5.0 (Windows NT 10.0; WOW64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/62.0.3202.9 Safari/537.36" #Chrome_Windows
                                    break;;
                                    Firefox_Windows)
                                        ua="Mozilla/5.0 (Windows NT 10.0; WOW64; rv:56.0) Gecko/20100101 Firefox/56.0" #Firefox_Windows
                                    break;;
                                    Edge_Windows)
                                        ua="Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/52.0.2743.116 Safari/537.36 Edge/15.15063" #Edge_Windows
                                    break;;
                                    Firefox_Linux)
                                        ua="Mozilla/5.0 (X11; Linux i586; rv:31.0) Gecko/20100101 Firefox/31.0" #Firefox_Linux
                                    break;;
                                    Safari_MacOS)
                                        ua="Mozilla/5.0 (Macintosh; Intel Mac OS X 10_12_6) AppleWebKit/604.3.5 (KHTML, like Gecko) Version/11.0.1 Safari/604.3.5" #Safari_MacOS
                                    break;;
                                    Nenhum)
                                        echo "Executar navegação forçada sem user-agent."
                                    break;;
                                esac
                            done
                            echo "Executando força bruta com Feroxbuster"

                            # Configurar opção do Feroxbuster para usar navegador selecionado pelo usuário
                            if [[ -z "${ua}" ]]; then
                                useragentOption=""
                            else
                                useragentOption="-a $ua"
                            fi

                            # Executar Feroxbuster com dicionário e user-agent selecionados, gerando arquivo query.json com o resultado
                            $ferox -E -I "${ignore_files}" -e -s 200 -w "./dicionario.txt" -u "$protocol"://"$ip_target" -r -k "${useragentOption}" -o query.json --json
                        fi

##################################
## BUSCA DE CHAVES AUTOMATIZADA ##
##################################

                        # Configurar opção do curl para usar navegador selecionado pelo usuário
                        if [[ -z "${ua}" ]]; then
                            curlUAOption=""
                        else
                            curlUAOption="-A $ua"
                        fi

                        # Identificar se já existe arquivo urls com lista de URLs a serem verificadas
                        if [ ! -f "urls" ]; then
                            # Extrai todas URLs do arquivo query.json, ignorando aquelas com extensões pré-definidas para ignorar
                            # Para cada arquivo chamado query*...
                            for file in query*; do
                                # Se a ferramenta JQ estiver disponível...
                                if [ "$(command -v jq)" ]; then
                                    # Extrai todas strings de campo "URL" do arquivo (jq '.url'), 
                                    # organiza e remove duplicatas (sort -u)
                                    # filtra apenas as que começam com o protocolo selecionado (grep -E "^${protocol}")
                                    # filtra excluindo arquivos com extensões pré-definidas
                                    # Saída para o arquivo "urls"
                                    jq -r '.url' < "$file" \
                                        | sort -u \
                                        | grep -E "^$protocol" \
                                        | grep -v -E "${ignore_files//,/|}" \
                                        >> urls 2>/dev/null
                                else
                                    # Se a ferramenta JQ não estiver disponível...
                                    # Extrai todas strings de campo "URL" do arquivo (sed -r -n 's#.+"url":"([^"]+)".+#\1#p'), 
                                    # organiza e remove duplicatas (sort -u)
                                    # filtra apenas as que começam com o protocolo selecionado (grep -E "^${protocol}")
                                    # filtra excluindo arquivos com extensões pré-definidas
                                    # Saída para o arquivo "urls"
                                    sed -r -n 's#.+"url":"([^"]+)".+#\1#p' "$file" \
                                        | sort -u \
                                        | grep "${protocol}" \
                                        | grep -v -E "${ignore_files//,/|}" \
                                        >> urls
                                fi
                            done

                            # Se a contagem de URLs com robots for menor que 2...
                            if [ "$(grep -Ec ".*robots.*" urls)" -lt 2 ]; then
                                # Verifica se existe `alvo/robots.txt`
                                if [ "$(curl "$curlUAOption" -s -w "%{http_code}" "$protocol://$ip_target/robots.txt" -o robots.txt)" -eq 200 ]; then
                                    # Filtra apenas URLs em "allow" e "disallow", ignorando outras instruções
                                    sed -n -r "s#(Disa|A)llow: (.+)#$protocol://$ip_target\2#p" robots.txt >> urls
                                fi
                            fi

                            # Se a contagem de URLs com sitemap for menor que 2...
                            if [ "$(grep -Ec ".*sitemap.*" urls)" -lt 2 ]; then
                                # Verifica se existe `alvo/sitemap.xml`
                                if [ "$(curl "$curlUAOption" -s -w "%{http_code}" "$protocol://$ip_target/sitemap.xml" -o sitemap.xml)" -eq 200 ]; then
                                    # Extrai todas URLs com o protocolo do alvo (sed -n -r "s#.+($protocol://[^<\"]+).+#\1#p")
                                    # Filtra ocorrências de "sitemaps" e "w3" (grep -v "sitemaps\|w3")
                                    sed -n -r "s#.+($protocol://[^<\"]+).+#\1#p" sitemap.xml \
                                        | grep -v "sitemaps\|w3" \
                                        >> urls
                                fi
                            fi
                        fi
                        # Organiza todas URLs do arquivo `urls` e coloca no arquivo `urls-sorted`
                        sort urls -u > urls-sorted
                        # Remove o arquivo `urls`
                        rm urls 2>/dev/null
                    fi

                fi

                # Verifica se existe o arquivo `urls-sorted`
                if [ -f urls-sorted ]; then
                    echo "Verificando chaves nas URLs"

                    # Executa loop, cada URL no arquivo `urls-sorted` vira a variável $dirs na sua vez
                    while read -r dirs; do
                        if [[ "${debug_mode}" == "ON" ]]; then
                            echo "DEBUG: DIRS: \"$dirs\""
                        fi

                        # Bloco para preparar print de acordo com o tamanho da tela do terminal
                        # Dessa maneira, caso não exista chave, a mensagem exibindo o caminho atualmente testado é sobrescrita pela próxima
                        result=$(printf "dirs: %s >" "$dirs")
                        # identifica a largura da tela com `tput cols` e subtrai o tamanho do result com ${#<variável>}
                        tamanho=$(( "$(tput cols)" - ${#result} ))
                        # Usa a função printf para colocar quantos espaços for necessário
                        brancos=$(printf "%-${tamanho}s" " ")
                        # Finalmente, usa printf para exibir o resultado + espaços em branco, sobrescrevendo a linha anterior
                        printf "%s%s\r" "$result" "$brancos"

                        # substitui o IP de volta pelo domínio
                        dirs_URI=${dirs//"$ip_target"/"$URI"}
                        if [[ "${debug_mode}" == "ON" ]]; then
                            echo "DEBUG: dirs_URI: \"$dirs_URI\""
                        fi

                        # Consulta direta na URL removendo byte nulo (tr -d '\0')
                        directquery=$(curl "$curlUAOption" -s "$dirs_URI" 2>/dev/null | tr -d '\0')
                        if [[ "${debug_mode}" == "ON" ]]; then
                            printf "\n"
                            echo "DEBUG: curl (1): \"$directquery\""
                        fi

                        # Verifica se existem links no conteúdo retornado pela consulta
                        if [[ "$directquery" == *"a href"* ]] ; then
                            # Extrai URLs identificadas em código HTML "a href"
                            file=$(sed -n -r 's#.+a href="([^"]+)".+#\1#p' <<< "$directquery")
                            # Faz nova consulta em cima do link identificado
                            # Filtra linhas que tenham a palavra "key" (grep -a -i key)
                            # Filtra ocorrências de "key" indesejadas configuradas na regex $ignore_keys (grep -a -i -v -E "$ignore_keys")
                            key=$(curl "$curlUAOption" -s -k "$dirs/$file" 2>/dev/null | grep -a -i key | grep -a -i -v -E "$ignore_keys")
                            if [[ "${debug_mode}" == "ON" ]]; then
                                printf "\n"
                                echo "DEBUG: curl (2): \"$key\""
                            fi
                        elif [[ "$directquery" == *"request.open"* ]] ; then
                            # Essa parte é mais voltada para analisar APIs encontradas
                            # Extrai URLs começando com "/" de links e coloca no arquivo "endpoints"
                            sed -n -r 's#.+"(/[^"]+)".+#\1#p' <<< "${directquery}" > endpoints
                            # Executa loop para cada entrada no arquivo endpoints
                            while read -r endpoint; do
                                # Configura variávei $dirs para ser igual a $protocol://$URI$endpoint (lembrando que $endpoint começa com "/")
                                dirs="$protocol://$URI$endpoint"
                                # Efetua consulta a $dirs utilizando o cURL
                                consultadireta=$(curl "$curlUAOption" -s -k "$dirs" 2>/dev/null)
                                # Tenta identificar chaves no resultado da consulta direta
                                # "tr -d '\n'" remove quebras de linha
                                # greps filtram pela existência da palavra key e remoção de itens listados em $ignore_keys
                                # sed tenta extrair strings maiores que 13 caracteres
                                key=$(tr -d '\n' <<< "$consultadireta" | grep -a -i key | grep -a -i -v -E "$ignore_keys" | sed -n -r 's#.+\b[Kk][Ee][Yy]\b.+\b([a-zA-Z0-9_-]{13,})\b.+#\1#p')
                            done < endpoints
                        else
                            # se não houver links (href) nem requests (APIs), tenta filtrar linhas com chave no conteúdo de $directquery
                            key=$(grep -a -i key <<< "$directquery" | grep -a -i -v -E "$ignore_keys")
                        fi

                        if [[ "${debug_mode}" == "ON" ]]; then
                            printf "\n"
                            echo "DEBUG: key: \"$key\""
                        fi

                        # Se existir a variável $key...
                        if [ -n "$key" ]; then
                            if [[ "${debug_mode}" == "ON" ]]; then
                                echo ""
                                echo "DEBUG: >>>> KEY ENCONTRADA <<<< "
                                echo ""
                            fi

                            # prepara em $result o que será exibido no terminal, com URL e chave encontrada
                            result=$(printf "dirs: %s - key: \"%s\"" "$dirs" "$key")
                            # se o tamanho de $result for maior que a quantidade de colunas do terminal
                            if [[ ${#result} -gt $(tput cols) ]]; then
                                # Primeiro, prepara o que será exibido em $result
                                result=$(printf "dirs: %s" "$dirs")
                                # Segundo, conta quantos caracteres há em $result e subtrai da quantidade de colunas do terminal
                                tamanho=$(( "$(tput cols)" - ${#result} ))
                                # Terceiro, prepara espaços em branco conforme a diferença encontrada em $tamanho
                                brancos=$(printf "%-${tamanho}s" " ")
                                # Finalmente, exibe no terminal a URL e os espaços em branco, para sobrescrever quaisquer caracteres que sobrassem de uma linha exibida anteriormente
                                # Inclui uma quebra de linha ao final, para manter a linha exibida no histórico do terminal
                                printf "%s%s\r\n" "$result" "$brancos" | tee -a chaves.txt

                                # Então, joga cada trecho contendo "key", mais (até) 3 caracteres antes e (até) 30 caracteres depois no arquivo keys
                                grep -o -P '.{0,3}key.{0,30}' <<< "$key" > keys
                                # Para cada entrada no arquivo keys
                                while read -r eachkey; do
                                    # Prepara o que será exibido em $result
                                    result=$(printf "    > \"%s\"" "$eachkey")
                                    # Conta quantos caracteres há em $result e subtrai da quantidade de colunas do terminal
                                    tamanho=$(( "$(tput cols)" - ${#result} ))
                                    # Prepara espaços em branco conforme a diferença encontrada em $tamanho
                                    brancos=$(printf "%-${tamanho}s" " ")
                                    # Exibe a chave encontrada no terminal e os espaços em branco, para sobrescrever quaisquer caracteres que sobrassem de uma linha exibida anteriormente
                                    # Inclui uma quebra de linha ao final, para manter a linha exibida no histórico do terminal
                                    printf "%s%s\r\n" "$result" "$brancos" \
                                        | tee -a chaves.txt
                                done < keys
                            else
                                # se o tamanho de $result for menor que a quantidade decolunas do terminal
                                # determina a diferença entre o tamanho de $result e a quantidade de colunas
                                tamanho=$(( "$(tput cols)" - ${#result} ))
                                # gera uma sequência de espaços em branco do tamanho da diferença determinada
                                brancos=$(printf "%-${tamanho}s" " ")
                                # exibe $result mais espaços em branco para sobrescrever quaisquer caracteres que sobrassem de uma linha exibida anteriormente
                                    # Inclui uma quebra de linha ao final, para manter a linha exibida no histórico do terminal
                                printf "%s%s\r\n" "$result" "$brancos" \
                                    | tee -a chaves.txt
                            fi
                        fi

                        # Verifica a existência de registros para aquela URI no Wayback Machine do Internet Archive
                        query=$(curl "$curlUAOption" -s "https://web.archive.org/web/timemap/link/$dirs_URI")
                        if [[ "${debug_mode}" == "ON" ]]; then
                            printf "\n"
                            echo "DEBUG: curl (3): \"$query\""
                        fi
                        # Extrai todas as ocorrências de registros para o arquivo mementos
                        # "Mementos" é como o próprio sistema do Wayback Machine referencia as ocorrências
                        sed -n -r "s#.+(https://web.archive.org/web/[0-9]+/[^>]+).+#\1#p" <<< "$query" > mementos

                        # Conta quantas ocorrências foram encontradas
                        count_mementos=$(wc -l mementos | cut -d' ' -f1)
                        if [[ "${debug_mode}" == "ON" ]]; then
                            echo "DEBUG: count_mementos: \"$count_mementos\""
                        fi
                        # Se a quantidade de mementos for maior que zero
                        if [[ "$count_mementos" -gt 0 ]]; then
                            # Para cada memento...
                            while read -r memento; do
                                if [[ "${debug_mode}" == "ON" ]]; then
                                    echo "DEBUG: MEMENTO: \"$memento\""
                                fi

                                # Exibe no terminal qual memento está sendo processado
                                result=$(printf "memento: %s >" "$memento")
                                # Verifica a diferença no tamanho entre a quantidade de colunas do terminal e o tamanho do $result
                                tamanho=$(( "$(tput cols)" - ${#result} ))
                                # Gera uma sequência de espaços em branco igual à diferença de tamanho identificada
                                brancos=$(printf "%-${tamanho}s" " ")
                                # Exibe no terminal o resultado mais espaços em brancos, sem quebra de linha mas com retorno ao início dela
                                # Isso permite que a próxima linha sobrescreva a linha atual, mostrando a progressão do processamento
                                printf  "%s%s\r" "$result" "$brancos"

                                # Executa uma consulta ao memento identificado
                                query=$(curl "$curlUAOption" -s -k "$memento" 2>/dev/null | tr -d '\0')
                                if [[ "${debug_mode}" == "ON" ]]; then
                                    printf "\n"
                                    echo "DEBUG: curl (4): \"$query\""
                                fi

                                if [[ "$query" == *"iframe id=\"playback\""* ]] ; then
                                    # alguns resultados de mementos às vezes (por motivos não identificados) retornam "playbacks" ao invés de páginas
                                    # um "playback" é uma página intermediária com um link para o memento em si
                                    query=$(sed -n -r 's#.+playback" src="([^"]+)".+#\1#p' <<< "$query" | xargs curl --output - )
                                    if [[ "${debug_mode}" == "ON" ]]; then
                                        printf "\n"
                                        echo "DEBUG: curl (5): \"$query\""
                                    fi
                                fi
                                # tenta identificar chaves em $query, excluindo os itens de $ignore_keys
                                key=$(grep -a -i key <<< "$query" | grep -a -i -v -E "$ignore_keys")

                                # se $key não estiver vazia...
                                if [ -n "$key" ]; then
                                    if [[ "${debug_mode}" == "ON" ]]; then
                                        echo "DEBUG: KEY_MEMENTOS: \"$key\""
                                        echo ""
                                        echo "DEBUG: >>>> KEY MEMENTOS ENCONTRADA <<<< "
                                        echo ""
                                    fi

                                    # prepara em $result o que será exibido no terminal, com URL e chave encontrada
                                    result=$(printf "memento: %s - key: \"%s\"" "$memento" "$key")
                                    # se o tamanho de $result for maior que a quantidade de colunas do terminal
                                    if [[ ${#result} -gt $(tput cols) ]]; then
                                        # Primeiro, prepara o que será exibido em $result
                                        result=$(printf "dirs: %s" "$dirs")
                                        # Segundo, conta quantos caracteres há em $result e subtrai da quantidade de colunas do terminal
                                        tamanho=$(( "$(tput cols)" - ${#result} ))
                                        # Terceiro, prepara espaços em branco conforme a diferença encontrada em $tamanho
                                        brancos=$(printf "%-${tamanho}s" " ")
                                        # Finalmente, exibe no terminal a URL e os espaços em branco, para sobrescrever quaisquer caracteres que sobrassem de uma linha exibida anteriormente
                                        # Inclui uma quebra de linha ao final, para manter a linha exibida no histórico do terminal
                                        printf "%s%s\r\n" "$result" "$brancos" \
                                            | tee -a chaves.txt

                                        # Então, joga cada trecho contendo "key", mais (até) 3 caracteres antes e (até) 30 caracteres depois no arquivo keys
                                        grep -a -i -o -P '.{0,3}key.{0,30}' <<< "$key" \
                                            | grep -a -i -v -E "$ignore_keys" \
                                            > keys
                                        # Para cada entrada no arquivo keys
                                        while read -r eachkey; do
                                            # Prepara o que será exibido em $result
                                            result=$(printf "    > \"%s\"" "$eachkey")
                                            # Conta quantos caracteres há em $result e subtrai da quantidade de colunas do terminal
                                            tamanho=$(( "$(tput cols)" - ${#result} ))
                                            # Prepara espaços em branco conforme a diferença encontrada em $tamanho
                                            brancos=$(printf "%-${tamanho}s" " ")
                                            # Exibe a chave encontrada no terminal e os espaços em branco, para sobrescrever quaisquer caracteres que sobrassem de uma linha exibida anteriormente
                                            # Inclui uma quebra de linha ao final, para manter a linha exibida no histórico do terminal
                                            printf "%s%s\r\n" "$result" "$brancos" \
                                                | tee -a chaves.txt
                                        done < keys
                                    else
                                        # se o tamanho de $result for menor que a quantidade decolunas do terminal
                                        # determina a diferença entre o tamanho de $result e a quantidade de colunas
                                        tamanho=$(( "$(tput cols)" - ${#result} ))
                                        # gera uma sequência de espaços em branco do tamanho da diferença determinada
                                        brancos=$(printf "%-${tamanho}s" " ")
                                        # exibe $result mais espaços em branco para sobrescrever quaisquer caracteres que sobrassem de uma linha exibida anteriormente
                                            # Inclui uma quebra de linha ao final, para manter a linha exibida no histórico do terminal
                                        printf "%s%s\r\n" "$result" "$brancos" \
                                            | tee -a chaves.txt
                                    fi
                                fi
                            done < mementos
                        fi
                    done < urls-sorted
                fi

##################################
## EXIBE RESULTADOS ENCONTRADOS ##
##################################

                if [ -f "chaves.txt" ]; then
                    # Se existe arquivo chaves.txt...

                    # Exibe banner no terminal
                    cat <<EOF | tee -a resultado.txt

    ===========================
    == CHAVES MAIS PROVÁVEIS ==
    ===========================

EOF
                    # extrair possíveis chaves (sequências de 13 ou mais letras e números) do arquivo chaves.txt
                    # organizar e excluir entradas duplicadas
                    # usa o sed para identificar a linha da chave e pegar a URL onde ela foi encontrada
                    # organizar e excluir entradas duplicadas, exibe na tela e escreve no arquivo resultado.txt anexando ao final dele
                    sed -n -r 's#.+[Kk][Ee][Yy].+\b([a-zA-Z0-9_]{13,})\b.+#\1#p' chaves.txt \
                        | sort -u \
                        | xargs -I '{}' bash -c "sed -n -r \"s#.+\bhttps?://[^/]+/([^ ]+)\b.+\b({})\b.+#${protocol}://${URI}/\1 - \2#p\" chaves.txt | sort -u | tee -a resultado.txt"

                    # Identifica informações de servidor e plataforma
                    # o primeiro sed extrai todas extensões de arquivos identificados no arquivo urls-sorted, organiza e exclui duplicados
                    # para cada uma das extensões, pega uma URL no arquivo urls-sorted
                    # para cada arquivo, faz um curl --head
                    # filtra apenas as informações "Server" e "X-Powered-By"
                    plattech=$(sed -n -r 's#.+\.([^./ ]{2,4})$#\1#p' < urls-sorted \
                        | sort -u \
                        | xargs -I{} bash -c "grep \"\.{}\" urls-sorted" \
                        | xargs -I{} bash -c "curl \"$curlUAOption\" -v -s --head {} 2>&1" \
                        | sed -n -r 's#.+(Server|X-Powered-By): ([^ -]+).+#\2#p' \
                        | sort -u)

                    # Exibe o banner e o resultado em tela, e escreve no arquivo resultado.txt
                    cat <<EOF | tee -a resultado.txt

    ===============================
    == PLATAFORMAS E TECNOLOGIAS ==
    ===============================

${plattech}

    =========
    == FIM ==
    =========

EOF
                fi
            fi
        fi
    fi
fi