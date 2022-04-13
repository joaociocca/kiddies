#!/usr/bin/env bash

protocol=${1%:*}
URI=${1##*/}

ignore_keys="srvkey|(primary |fa-(.+)?)key|key(word|hooks|board|frames|\.txt|_map)"
ignore_files="gif,jpg,jpeg,bmp,psd,png,ttf,woff,eot"

ferox="$(which feroxbuster)"
if [[ -z "${ferox}" ]]; then
    ferox="$(find / -name feroxbuster -type f -print -quit 2>/dev/null)"
    if [[ -z "${ferox}" ]]; then
        cat <<EOF

    Comando "feroxbuster" não existe no sistema.
    Ferramenta disponível em: https://github.com/epi052/feroxbuster

    Instalação rápida no Linux: 
cd ~
curl -sL https://raw.githubusercontent.com/epi052/feroxbuster/master/install-nix.sh | bash

EOF
    else
        if [[ "${debug_mode}" == "ON" ]]; then
            echo "Iniciando..."
        fi

        if [[ "$2" == "DEBUG" ]]; then
            debug_mode="ON"
        fi

        ip_target="$(nslookup "$URI" | sed -n -r 's#Address: (.+)#\1#p')"
        if [[ "${debug_mode}" == "ON" ]]; then
            echo "NSLookup result: $ip_target"
        fi

        if [ ! -f urls-sorted ]; then
            if [ -n "$ip_target" ]; then

                seclists=$(find / -iname "seclists" -type d -print -quit 2>/dev/null)
                if [ ! -d "${seclists}" ]; then
                    cat << EOF

Não encontrado seclists. Favor clonar de https://github.com/danielmiessler/SecLists.

EOF
                else
                    if [[ "${debug_mode}" == "ON" ]]; then
                        echo "seclists encontrado"
                    fi

                    if [ ! -f "query.json" ]; then
                        # Escolher a(s) wordlists a ser(em) usada(s)
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

                        find ${seclists}/Discovery/Web-Content/ -regextype posix-extended -regex ".+(${regexTamanho}).+" | rev | cut -d'/' -f1 | rev | sort > wordlists
                        select escolhaWordlist in $(<wordlists);do
                            wordlist="${seclists}/Discovery/Web-Content/${escolhaWordlist}"; break;
                        done
                        commonpt=$(find ${seclists}/Discovery/Web-Content/common-and-portuguese.txt)
                        if [[ -n "${commonpt}" ]]; then
                            cat $wordlist $commonpt | sort -u > dicionario.txt
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

                        # find /usr/share/seclists/ -regextype posix-extended -regex '.+(directory.+big|raft-large).+' -type f
                        # /usr/share/seclists/Discovery/Web-Content/directory-list-2.3-big.txt
                        if [[ -z "${ua}" ]]; then
                            useragentOption=""
                        else
                            useragentOption="-a $ua"
                        fi
                        
                        $ferox -E -I "${ignore_files}" -e -s 200 -w "./dicionario.txt" -u "$protocol"://"$ip_target" -r -k "${useragentOption}" -o query.json --json
                        # feroxbuster -e -s 200 -w /usr/share/seclists/Discovery/Web-Content/common-and-portuguese.txt -u "$protocol"://"$ip_target" -r -k -a "Mozilla/5.0 (Windows NT 10.0; WOW64; rv:56.0) Gecko/20100101 Firefox/56.0" -o query-pt.json --json
                    fi

                    if [[ -z "${ua}" ]]; then
                        curlUAOption=""
                    else
                        curlUAOption="-A $ua"
                    fi

                    if [ ! -f "urls" ]; then
                        for file in query*; do
                            if [ "$(command -v jq)" ]; then
                                jq -r '.url' < "$file" | sort -u | grep "$protocol" | grep -v -E "${ignore_files//,/|}" >> urls 2>/dev/null
                            else
                                sed -r -n 's#.+"url":"([^"]+)".+#\1#p' "$file" | sort -u | grep "$protocol" | grep -v -E "${ignore_files//,/|}" >> urls
                            fi
                        done

                        if [ "$(grep -Ec ".*robots.*" urls)" -lt 2 ]; then
                            if [ "$(curl "$curlUAOption" -s -w "%{http_code}" "$protocol://$ip_target/robots.txt" -o robots.txt)" -eq 200 ]; then
                                sed -n -r "s#(Disa|A)llow: (.+)#$protocol://$ip_target\2#p" robots.txt >> urls
                            fi
                        fi

                        if [ "$(grep -Ec ".*sitemap.*" urls)" -lt 2 ]; then
                            if [ "$(curl "$curlUAOption" -s -w "%{http_code}" "$protocol://$ip_target/sitemap.xml" -o sitemap.xml)" -eq 200 ]; then
                                sed -n -r "s#.+($protocol://[^<\"]+).+#\1#p" sitemap.xml | grep -v "sitemaps\|w3" >> urls
                            fi
                        fi
                    fi
                    sort urls -u > urls-sorted
                    rm urls 2>/dev/null
                fi
            fi
        fi

        echo "Verificando chaves nas URLs"

        while read -r dirs; do
            if [[ "${debug_mode}" == "ON" ]]; then
                echo "DEBUG: DIRS: \"$dirs\""
            fi

            result=$(printf "dirs: %s >" "$dirs")
            tamanho=$(( "$(tput cols)" - ${#result} ))
            brancos=$(printf "%-${tamanho}s" " ")
            printf "%s%s\r" "$result" "$brancos"

            dirs_URI=${dirs//"$ip_target"/"$URI"}
            if [[ "${debug_mode}" == "ON" ]]; then
                echo "DEBUG: dirs_URI: \"$dirs_URI\""
            fi

            directquery=$(curl "$curlUAOption" -s "$dirs_URI" 2>/dev/null | tr -d '\0')
            if [[ "${debug_mode}" == "ON" ]]; then
                printf "\n"
                echo "DEBUG: curl (1): \"$directquery\""
            fi
            if [[ "$directquery" == *"a href"* ]] ; then
                file=$(sed -n -r 's#.+a href="([^"]+)".+#\1#p' <<< "$key")
                key=$(curl "$curlUAOption" -s -k "$dirs/$file" 2>/dev/null | grep -a -i key | grep -a -i -v -E "$ignore_keys")
                if [[ "${debug_mode}" == "ON" ]]; then
                    printf "\n"
                    echo "DEBUG: curl (2): \"$key\""
                fi
            elif [[ "$directquery" == *"request.open"* ]] ; then
                #search endpoints
                sed -n -r 's#.+"(/[^"]+)".+#\1#p' <<< $directquery > endpoints
                while read -r endpoint; do
                    dirs="$protocol://$URI$endpoint"
                    # query=$(curl "$curlUAOption" -s -k "$path" 2>/dev/null | grep -a -i key | grep -a -i -v -E "$ignore_keys")
                    key=$(curl "$curlUAOption" -s -k "$dirs" 2>/dev/null | tr -d '\n' | grep -a -i key | grep -a -i -v -E "$ignore_keys" | sed -n -r 's#.+\b[Kk][Ee][Yy]\b.+\b([a-zA-Z0-9_-]{13,})\b.+#\1#p')
                done < endpoints
            else
                key=$(grep -a -i key <<< "$directquery" | grep -a -i -v -E "$ignore_keys")
            fi

            if [[ "${debug_mode}" == "ON" ]]; then
                printf "\n"
                echo "DEBUG: key: \"$key\""
            fi
            if [ -n "$key" ]; then
                if [[ "${debug_mode}" == "ON" ]]; then
                    echo ""
                    echo "DEBUG: >>>> KEY ENCONTRADA <<<< "
                    echo ""
                fi

                # se o tamanho da chave for maior que a quantidade de colunas do terminal
                result=$(printf "dirs: %s - key: \"%s\"" "$dirs" "$key")
                if [[ ${#result} -gt $(tput cols) ]]; then
                    #printa a URL contendo keys
                    result=$(printf "dirs: %s" "$dirs")
                    tamanho=$(( "$(tput cols)" - ${#result} ))
                    brancos=$(printf "%-${tamanho}s" " ")
                    printf "%s%s\r\n" "$result" "$brancos" | tee -a chaves.txt

                    grep -o -P '.{0,3}key.{0,30}' <<< "$key" > keys
                    while read -r eachkey; do
                        result=$(printf "    > \"%s\"" "$eachkey")
                        tamanho=$(( "$(tput cols)" - ${#result} ))
                        brancos=$(printf "%-${tamanho}s" " ")
                        printf "%s%s\r\n" "$result" "$brancos" | tee -a chaves.txt
                    done < keys
                else
                    tamanho=$(( "$(tput cols)" - ${#result} ))
                    brancos=$(printf "%-${tamanho}s" " ")
                    printf "%s%s\r\n" "$result" "$brancos" | tee -a chaves.txt
                fi
            fi

            # count mementos on wayback machine
            query=$(curl "$curlUAOption" -s "https://web.archive.org/web/timemap/link/$dirs_URI")
            if [[ "${debug_mode}" == "ON" ]]; then
                printf "\n"
                echo "DEBUG: curl (3): \"$query\""
            fi
            sed -n -r "s#.+(https://web.archive.org/web/[0-9]+/[^>]+).+#\1#p" <<< "$query" > mementos

            count_mementos=$(wc -l mementos | cut -d' ' -f1)
            if [[ "${debug_mode}" == "ON" ]]; then
                echo "DEBUG: count_mementos: \"$count_mementos\""
            fi
            if [[ "$count_mementos" -gt 0 ]] && [[ ! "$dirs_URI" == "$protocol://$URI" ]]; then
                while read -r memento; do
                    if [[ "${debug_mode}" == "ON" ]]; then
                        echo "DEBUG: MEMENTO: \"$memento\""
                    fi

                    result=$(printf "memento: %s >" "$memento")
                    tamanho=$(( "$(tput cols)" - ${#result} ))
                    brancos=$(printf "%-${tamanho}s" " ")
                    printf  "%s%s\r" "$result" "$brancos"

                    query=$(curl "$curlUAOption" -s -k "$memento" 2>/dev/null | tr -d '\0')
                    if [[ "${debug_mode}" == "ON" ]]; then
                        printf "\n"
                        echo "DEBUG: curl (4): \"$query\""
                    fi

                    if [[ "$query" == *"iframe id=\"playback\""* ]] ; then
                        query=$(sed -n -r 's#.+playback" src="([^"]+)".+#\1#p' <<< "$query" | xargs curl --output - )
                        if [[ "${debug_mode}" == "ON" ]]; then
                            printf "\n"
                            echo "DEBUG: curl (5): \"$query\""
                        fi
                    fi
                    key=$(grep -a -i key <<< "$query" | grep -a -i -v -E "$ignore_keys")

                    if [ -n "$key" ]; then
                        if [[ "${debug_mode}" == "ON" ]]; then
                            echo "DEBUG: KEY_MEMENTOS: \"$key\""
                            echo ""
                            echo "DEBUG: >>>> KEY MEMENTOS ENCONTRADA <<<< "
                            echo ""
                        fi

                        # se o tamanho da chave for maior que a quantidade de colunas do terminal
                        result=$(printf "memento: %s - key: \"%s\"" "$memento" "$key")
                        if [[ ${#result} -gt $(tput cols) ]]; then
                            #printa a URL contendo keys
                            result=$(printf "memento: %s" "$memento")
                            tamanho=$(( "$(tput cols)" - ${#result} ))
                            brancos=$(printf "%-${tamanho}s" " ")
                            printf "%s%s\r\n" "$result" "$brancos" | tee -a chaves.txt

                            grep -a -i -o -P '.{0,3}key.{0,30}' <<< "$key" | grep -a -i -v -E "$ignore_keys" > keys
                            while read -r eachkey; do
                                result=$(printf "    > %s" "$eachkey")
                                tamanho=$(( "$(tput cols)" - ${#result} ))
                                brancos=$(printf "%-${tamanho}s" " ")
                                printf "%s%s\r\n" "$result" "$brancos" | tee -a chaves.txt
                            done < keys
                        else
                            tamanho=$(( "$(tput cols)" - ${#result} ))
                            brancos=$(printf "%-${tamanho}s" " ")
                            printf "%s%s\r\n" "$result" "$brancos" | tee -a chaves.txt
                        fi

                    fi
                done < mementos
            fi
        done < urls-sorted

#        cat << EOF

# ================================================
# == RESULTADO DA VARREDURA ======================
# ================================================

# EOF
#         if [ -f "chaves.txt" ]; then
#             grep -Ei --color=auto 'key|$' chaves.txt

        cat << EOF

===========================
== CHAVES MAIS PROVÁVEIS ==
===========================

EOF
        sed -n -r 's#.+[Kk][Ee][Yy].+\b([a-zA-Z0-9_]{13,})\b.+#\1#p' chaves.txt | sort -u | xargs -I '{}' bash -c "sed -n -r \"s#.+\bhttps?://[^/]+/([^ ]+)\b.+\b({})\b.+#${protocol}://${URI}/\1 - \2#p\" chaves.txt | sort -u | tee -a resultado.txt"
    fi
fi

plattech=$(cat urls-sorted \
| sed -n -r 's#.+\.([^./ ]{2,4})$#\1#p' \
| sort -u \
| tr '\n' '\0' \
| xargs -0 -I{} bash -c "grep \"\.{}\" urls-sorted | head -1" \
| tr '\n' '\0' \
| xargs -0 -I{} bash -c "curl \"$curlUAOption\" -v -s {} 2>&1" \
| sed -n -r 's#.+(Server|X-Powered-By): ([^ -]+).+#\2#p' \
| sort -u)

cat << EOF

===============================
== PLATAFORMAS E TECNOLOGIAS ==
===============================

${plattech}

=========
== FIM ==
=========
EOF