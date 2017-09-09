#! /bin/bash

# Dev's: Vinícius Aires Barros,
#	   Herik Magalhães Serra
# Universidade de São Paulo - USP
# Istituto de Ciências Matemáticas e de Computação - ICMC
# Laboratório de Sistemas Distribuídos e Programação Concorrente - LASDPC

################################################################################
# FUNÇÕES DE TRATAMENTO DE SINAIS
################################################################################

# Tratamento de sinais do wget_gui
# $1 é para remover os arquivos baixados
wget_sig()
{
    set +e
    rm "wget.log" 2> /dev/null
    rm "$1" 2> /dev/null
}


# Tratamento de sinais do gzip_gui
# $1 nome da pasta a ser removida
gzip_sig()
{
    set +e
    rm -R "$1" 2> /dev/null
    rm "ext.log" 2> /dev/null
}


# Tratamento dos sinais do viewer_gui
# $1 nome do arquivo de log a ser excluído
viewer_sig()
{
    set +e
    rm "$1" 2> /dev/null
#    pkill -TERM -P $2
}



################################################################################
# FUNÇÕES ÚTEIS
################################################################################


# Verifica se um programa ainda esta rodando
# $1 é o PID do programa
running()
{
    [ "$(ps -aux | grep -v grep | awk '{print $2}' | grep -w \"${1}\")" = "$1" ] &&
        return 0

    return 1
}


# Estima o total kbytes a ser extraidos
# $1 path do arquivo
gzip_t_size()
{
    local uncompr="$(zcat "$1" | wc --bytes)"
    local total="$(bc <<< "$uncompr / 1000")"
    echo "$total"
}


# Retorna a porcentagem em comparação com o total
# $1 pasta/arquivo atual a ser medido
# $2 total do valor
curr_percent()
{
    local curr="$(du -s "$1" | cut -f1)"
    local pcent="$(bc <<< "($curr * 100) / $2")"

    [ $pcent -gt 99 ] &&
        echo "100"    ||
        echo "$pcent"
}


# Remove a extensão do tar
# $1 nome do arquivo
rmv_ext()
{
    echo "$(sed "s/.tar.gz.*$//" <<< "$1")"
}


# Extrair arquivos .tar
# Renomeia a pasta extraida com o nome sem a extensão
# $1 arquivo a ser extraído
ext_rname()
{
    local name=$(rmv_ext "$1")
    tar -xvf "$1" --xform="s|^|$name/|S" 2>&1
}


# Retorna o nome do pacote a ser procurado
# $1: nome do pacote
dpkg_gselec()
{
    echo "$(dpkg --get-selections | egrep "^${1}$(printf '\t')" | cut -f1)"
}


################################################################################
# INTERFACES E CONTROLADORES
################################################################################

# Mostra o log de um programa que falhou
# $1 : comando que falhou
# $2 : arquivo de log a ser exibido
log_viewer()
{
    local box_w="$(bc <<< "$(tput cols) * 0.9" | cut -f1 -d.)"
    local box_h="$(bc <<< "$(tput lines) * 0.8" | cut -f1 -d.)"
    local box_x="$(bc <<< "$(tput cols) * 0.05" | cut -f1 -d.)"
    local box_y="$(bc <<< "$(tput lines) * 0.1" | cut -f1 -d.)"

    dialog                                         \
        --backtitle "Command \"\Zb$1\ZB\" failed!" \
        --title "Log File"                         \
        --colors                                   \
        --begin $box_y $box_x                      \
        --textbox "$2"                             \
        $box_h $box_w
}


# Pergunta se quer executar algo novamente
# $1 : comando que falhou
retry_box()
{
    trap "" SIGHUP SIGINT SIGTERM

    dialog                                         \
        --backtitle "Command \"\Zb$1\ZB\" failed!" \
        --title ""                                 \
        --colors                                   \
        --yesno "\nDo you want to try it again?"   \
        7 0

    return $?
}


# Mostra uma mensagem de erro e aborta
# $1: Títudo do erro (aceita cores)
# $2: Mensagem de erro (aceita \n e cores)
# $3: Estatus de erro (aceita cores)
error_box()
{
    trap "" SIGHUP SIGINT SIGTERM

    # Calcula o tamanho da tela baseado no texto
    local width=$(echo -e "$2" | wc -L)
    local width=$(bc <<< "$width + 4")

    # Calcula o tamanho da tela baseado no texto
    local height=$(echo -e "$2" | wc -l)
    local height=$(bc <<< "$height + 6")

    # Calcula o tamanho máximo disponível da tela
    local max_w="$(bc <<< "$(tput cols) * 0.9" | cut -f1 -d.)"
    local max_h="$(bc <<< "$(tput lines) * 0.7" | cut -f1 -d.)"

    # Substitui pelo máximo disponível, caso seja maior
    [ $width -gt $max_w ] && width=$max_w
    [ $height -gt $max_h ] && height=$max_h

    dialog                                 \
        --backtitle "\Zb$1\ZB Aborting..." \
        --title "Error"                    \
        --colors                           \
        --msgbox "\n$2"                    \
        $height $width

    clear
    exit $3
}


# Pergunta se o usuário que confirmar algo
# $1: Títudo do erro (aceita cores)
# $2: Mensagem de erro (aceita \n e cores)
confirm_box()
{
    trap "" SIGHUP SIGINT SIGTERM

    # Calcula o tamanho da tela baseado no texto
    local width=$(echo -e "$2" | wc -L)
    local width=$(bc <<< "$width + 4")

    # Calcula o tamanho da tela baseado no texto
    local height=$(echo -e "$2" | wc -l)
    local height=$(bc <<< "$height + 6")

    # Calcula o tamanho máximo disponível da tela
    local max_w="$(bc <<< "$(tput cols) * 0.9" | cut -f1 -d.)"
    local max_h="$(bc <<< "$(tput lines) * 0.7" | cut -f1 -d.)"

    # Substitui pelo máximo disponível, caso seja maior
    [ $width -gt $max_w ] && width=$max_w
    [ $height -gt $max_h ] && height=$max_h

    dialog               \
        --stdout         \
        --backtitle "$1" \
        --title ""       \
        --colors         \
        --yesno  "\n$2"  \
        $height $width

    return $?
}


# Mostra o resumo de algo
# Cuidado com o tamanho da tela!
# $1: backtitle (aceita cores)
# $2: tittle (aceita cores)
# $3: mensagem (aceita \n e cores)
brief_box()
{
    # Calcula o tamanho da tela baseado no texto
    local width=$(echo -e "$3" | wc -L)
    local width=$(bc <<< "$width + 4")

    # Calcula o tamanho da tela baseado no texto
    local height=$(echo -e "$3" | wc -l)
    local height=$(bc <<< "$height + 6")

    # Calcula o tamanho máximo disponível da tela
    local max_w="$(bc <<< "$(tput cols) * 0.9" | cut -f1 -d.)"
    local max_h="$(bc <<< "$(tput lines) * 0.7" | cut -f1 -d.)"

    # Substitui pelo máximo disponível, caso seja maior
    [ $width -gt $max_w ] && width=$max_w
    [ $height -gt $max_h ] && height=$max_h

    dialog               \
        --stdout         \
        --backtitle "$1" \
        --title "$2"     \
        --colors         \
        --msgbox "\n$3"  \
        $height $width
}


# Seleciona um diretório para instalação
# $1 backtitle
# $2 Diretório default
# $3 Nome do item a ser inserido
dinstall_box()
{
    trap "" SIGHUP SIGINT SIGTERM

    local stat="continue"
    while [ "$stat" = "continue" ]
    do
        # Dialog para escolha do dir
        dir=$(dialog             \
                --stdout         \
                --backtitle "$1" \
                --title ""       \
                --colors         \
                --dselect "$2"   \
            0 0)

        # Testa se o dir é válido
        if [ -d "$dir" ]
        then
            cd .
            cd $dir
            dir=$(pwd)

            # Testa se existe o item no dir
            [ ! -f "${dir}/${3}" -a ! -d "${dir}/${3}" ]  &&
            stat="exit"                               ||
            brief_box                              \
                "$1"                               \
                "Warning"                          \
                "Already exists \"$3\" in \"$dir\"!"
            cd - 1> /dev/null

        # Verifica se não foi escolhido nenhuma opção
        elif [ "$dir" = "" ]
        then
            stat="exit"
        else
            brief_box                                  \
                "$1"                                   \
                "Warning"                              \
                "Directory \"$dir\" does not exists!"
        fi
    done

    echo "$dir"
}


# Baixa pelo wget e mostra na interface gráfica
# $1 : URL
wget_gui()
{
    # para descobrir se o wget falhou
    set -e -o pipefail

    local file=$(basename "$1")
    trap "wget_sig \"$file\"" SIGHUP SIGINT SIGTERM

    local exp1='([0-9]|[0-9][0-9]|100)%'
    local exp2='([0-9]|[0-9][0-9]|100)'

    (wget "$1" 2>&1)                                  | \
    tee "wget.log"                                    | \
    egrep -o --line-buffered $exp1                    | \
    egrep -o --line-buffered $exp2                    | \
    dialog                                              \
        --backtitle "Executing \"\Zbwget "$1"\ZB\" ..." \
        --title "wGet"                                  \
        --colors                                        \
        --gauge "\nDownloading $file ...."              \
        8 80 0
}


# Verifica se o processo foi executado com sucesso
# $1 = URL
# código de retorno:
#  1: arquivo já existe
#  2: falha de download
xwget()
{
    local file=$(basename "$1")
    [ -f "$file" ] && return 1

    local stat=0
    while ! wget_gui "$1"
    do
        # Retorna ao padrão
        set +e
        sleep 1

        [ -f "wget.log" ] && log_viewer "wget $1" "wget.log"

        retry_box "wget $1"

        [ $? -eq 1 -o $? -eq 255 ] && stat=2 && break
    done

    # Retorna ao padrão
    set +e
    trap "" SIGHUP SIGINT SIGTERM
    sleep 1

    [ "$stat" = "0" ] && rm "wget.log" || return $stat
}


# Extrai arquivos e mostra na interface
# $1 é o nome do arquivo
# $2 é o diretório criado
gzip_gui()
{
    # Detecta se o tar falha
    set -e -o pipefail
    local file=$(basename "$1")
    trap "gzip_sig \"$2\"" SIGHUP SIGINT SIGTERM

    (ext_rname "$1" 1> "ext.log" 2> "ext.log")&
    local PID=$!

    (
        while running "$PID"
        do
            echo $(curr_percent "$(rmv_ext "$1")" "$(gzip_t_size "$1")")
        done

        running "$PID" && echo "100"

    ) | dialog                                                \
            --backtitle "Executing \"\Zbtar -xvf $1\ZB\" ..." \
            --title "gzip"                                    \
            --colors                                          \
            --gauge "\nExtracting $file ...."                 \
            8 80 0

    wait $PID
    return $?
}


# Controlador do gzip_gui
# $1 = nome do arquivo a ser extraído
# código de retorno:
#   1: extração falhou
xgzip()
{
    local dir=$(rmv_ext "$1")
    [ -f "$dir" ] && rm -R "$dir"

    local stat=0
    while ! gzip_gui "$1" "$dir"
    do
        set +e
        sleep 1

        [ -f "ext.log" ] && log_viewer "tar -xvf $1" "ext.log"

        retry_box "tar -xvf $1"

        [ $? -eq 1 -o $? -eq 255 ] && stat=1 && break
    done

    set +e
    trap "" SIGHUP SIGINT SIGTERM
    sleep 1

    [ "$stat" = "0" ] && rm "ext.log" || return $stat
}


# Interface para a visualização dos comandos
# $1 = comando completo
# s2 = nome do comando
# $3 = mensagem de operação
viewer_gui()
{
    set -e -o pipefail
    trap "viewer_sig \"${2}.log\"" SIGHUP SIGINT SIGTERM

    local box_w="$(bc <<< "$(tput cols) * 0.9" | cut -f1 -d.)"
    local box_h="$(bc <<< "$(tput lines) * 0.8" | cut -f1 -d.)"
    local box_x="$(bc <<< "$(tput cols) * 0.05" | cut -f1 -d.)"
    local box_y="$(bc <<< "$(tput lines) * 0.1" | cut -f1 -d.)"

    ($1 2>&1)                                 |  \
    tee "${2}.log"                            |  \
    dialog                                       \
        --backtitle "Executing \"\Zb$1\ZB\" ..." \
        --title "$2"                             \
        --colors                                 \
        --begin $box_y $box_x                    \
        --progressbox "$3"                       \
        $box_h $box_w
}


# Controlador do viewer_gui
# Mostra o progresso de qualquer comando
# $1 = comando completo
# $2 = nome do comando
# $3 = mensagem de operação
# Código de retorno:
#   1 : comando falhou
generic_viewer()
{
    local stat=0
    while ! viewer_gui "$1" "$2" "$3"
    do
        set +e
        sleep 1

        [ -f "${2}.log" ] && log_viewer "$1" "${2}.log"

        retry_box $1

        [ $? -eq 1 -o $? -eq 255 ] && stat=1 && break
    done

    set +e
    trap "" SIGHUP SIGINT SIGTERM
    sleep 1

    [ "$stat" = "0" ] && rm "${2}.log" || return $stat
}



################################################################################
# CONFIGURAÇÃO DO GSN
################################################################################

# Configura o GSN
# $1: onde o gsn foi instalado
# $2: JAVA_HOME
gsn_conf()
{
    local installDir="$1"
    local javaHome="$2"


    set -e -o pipefail


    # Mensagem de Progresso
    echo "Configuring javacOptions..."


    # recupera apenas o campo da variável javacOptions do arquivo build
    local javacOptionsOld=$(sed -rn "/javacOptions/ s/(.*Seq\()(.*)(\),)/\2/ p" \
                          "$installDir/build.sbt")


    # recupera o path do java da variável javacOptions
    local javaHomeOld=$(echo $javacOptionsOld | cut -f6 -d,)


    # elimina o '/' depois do path do JAVA_HOME, caso exista
    cd .
    cd $javaHome
    javaHome=$(pwd)
    cd - 1> /dev/null


    # cria um novo PATH
    javaHome="$javaHome/jre/lib/rt.jar"


    # recupera a versão do compilador java usado na máquina
    local javaVersion=$(javac -version 2>&1 | sed -nr "s/(^javac )(.*)/\2/ p" | cut -f1-2 -d.)


    # criar uma nova variável javacOpitions
    javacOptions="\"-source\", \"$javaVersion\", \"-target\", \
\"$javaVersion\", \"-bootclasspath\", \"$javaHome\""


    # adciona a nova variável javacOptions no arquivo build.sbt
    sed -ri "s?$javacOptionsOld?$javacOptions?" "$installDir/build.sbt"


    # Mensagem de progresso
    echo "Configuring application.conf..."


    # comenta as variáveis gsn.location, gsn.config e gsn.vsconfig do arquivo application.conf
    sed -i "s/^gsn.location/#gsn.location/;
            s/^gsn.config/#gsn.config/;
            s/^gsn.vslocation/#gsn.vslocation/" \
            "$installDir/gsn-services/conf/application.conf"


    # coloca novos endereços para gsn.location, gsnconfig e gsn.vsconfig
    sed -i "/#customize gsn location/a gsn.vslocation=\"$installDir/virtual-sensors\"" \
        "$installDir/gsn-services/conf/application.conf"
    sed -i "/#customize gsn location/a gsn.config=\"$installDir/conf/gsn.xml\""        \
        "$installDir/gsn-services/conf/application.conf"
    sed -i "/#customize gsn location/a gsn.location=\"$installDir\""                   \
        "$installDir/gsn-services/conf/application.conf"


    # Mensagem de progresso
    echo "Creating wrappers.properties hard link..."


    # cria um hard link do arquivo conf/wrappers.properties para ser gerado na pasta target do gsn-core
    rm "$installDir/gsn-core/src/main/resources/wrappers.properties"
    ln "$installDir/conf/wrappers.properties"                         \
        "$installDir/gsn-core/src/main/resources/wrappers.properties"


    # Mensagem de progresso
    echo "Configuring evolutions table..."


    # apaga as primeiras linhas do arquivo 1.sql para não gerar uma nova tabela sql
    sed -i "/# --- !Ups/i @@@" "$installDir/gsn-services/conf/evolutions/default/1.sql"
    sed -i "/# --- !Ups/i @#!" "$installDir/gsn-services/conf/evolutions/default/1.sql"
    sed -i "1,/@#!/d" "$installDir/gsn-services/conf/evolutions/default/1.sql"

    echo "Done!"
}


#########################################################################################
#   _    _              _                                                               #
#  | \  / |    /\    | | \   |                                                          #
#  |  \/  |   /  \   | |  \  |                                                          #
#  |      |  /----\  | |   \ |                                                          #
#  |      | /      \ | |    \|                                                          #
#                                                                                       #
#########################################################################################

# Retorno do Script:
#   2 : Usuário não é Root
#   3 : Não existe JAVA_HOME no PATH
#   4 : Usuário não deseja prosseguir
#   5 : Falhou ao baixar o GSN
#   6 : Não existe um ip para o host em /etc/hosts


# verifica se o usuário tem privilégio de root
[ ${USER} != "root" ]                                           &&
    echo "[ERROR] You need root privileges to run this script!" &&
    exit 2


# verifica se o usuário tem o dialog instalado
# instala, caso contrário
if [ "$(dpkg_gselec "dialog")" = ""  ]; then

    echo "Instaling dialog.... wait a moment..."

    while ! apt-get -y install dialog 2> /dev/null 1> /dev/null
    do
        sleep 2
        echo "Trying again... "
    done

fi


# Recupera o diretório do usuário
homeusr=$(getent passwd ${SUDO_USER} | cut -d: -f6)


# Faz um backup do .dialogrc, caso exista
[ -f "$homeusr/.dialogrc" ]                             &&
    cp -p "$homeusr/.dialogrc" "$homeusr/.dialogrc.old"


# Faz uma nova cópia do .dialogrc
dialog --create-rc "${homeusr}/.dialogrc"


# Verifica se a variável JAVA_HOME foi configurada
javaHome=$(sudo -i -u ${SUDO_USER} env | grep JAVA_HOME | sed -rn "s#^JAVA_HOME=## p")
if [ ! $javaHome ]; then

    error_box                                       \
        "Installation Failed!"                      \
        "\$JAVA_HOME is not visible for all users!" \
        "3"

fi


# verifica se existe um endereço ip para o host em /etc/hosts
host=$(uname -n)
if [ "$(grep -v "#" /etc/hosts | grep -o "$host")" == "" ]
then
    error_box                                                          \
        "Installation Failed!"                                         \
        "Could not find a IP Address for \"$host\" in \"/etc/hosts\"." \
        "6"
fi


# Mensagem Inicial
welcome=\
'   This script will help you to install Global\n
Sensor Networks and its dependencies. After this,\n
you will be able to run the modules gsn-core and\n
gsn-services on your system.\n\n\n
To interact with the interface:\n\n
    Use ↑, ↓, ←, → and <TAB> to navegate.\n
    Use <SPACE> to autocomplete.\n
    Use <PGUP> <PGDOWN> to see vertical contents.\n
    Use <ENTER> to confirm.\n\n\n
This installation includes:\n\n
   # gsn-2.0.1\n
   # dialog (installed)\n
   # sbt\n
   # nodejs\n
   # npm\n
   # bower\n
   # python3\n
   # python-dev\n
   # python-setuptools\n
   # python-virtualenv\n
   # pip'


# Motra o que será instalado e pede confirmação
brief_box                                                     \
    "\ZbWelcome to Instalation of Global Sensor Networks!\ZB" \
    "Welcome!"                                                \
    "$welcome"


# Pergunta se dejeja continuar
confirm_box                                                   \
    "\ZbWelcome to Instalation of Global Sensor Networks!\ZB" \
    "Would you want to continue?"


# Sai do programa e retorna o código correspondente
[ "$?" = 1 -o "$?" = 255 ] && clear && exit 4


# Tela para escolher o diretório de instalação
installDir=$(dinstall_box                                     \
                "choose a \ZbInstall Directory\ZB for gsndev" \
                "/opt"                                        \
                "gsndev")


# Se não for escolhido nenhum diretório, aborta
[ "$installDir" = "" ]                      &&
error_box "Installation Failed!"            \
    "It's not possbile to continue!" "4"


# Diretório de download
downloadDir="/tmp/gsndev"


# Diretório onde tudo será baixado
mkdir /tmp/gsndev 2> /dev/null


# Diretório de download
cd /tmp/gsndev


# Baixa o gsn
url="https://github.com/LSIR/gsn/archive/gsn-release-2.0.1.tar.gz"
xwget $url


# Retorna o erro quando não consegue baixar
[ "$?" = 2 ]                                &&
error_box "Installation Failed!"            \
    "It's not possbile to continue!" "4"


# Extrai o GSN
xgzip gsn-release-2.0.1.tar.gz


# Adiciona a chave do servidor no arquivo .list
key="deb https://dl.bintray.com/sbt/debian /"
[ ! -f /etc/apt/sources.list.d/sbt.list ]          &&
    echo $key >> /etc/apt/sources.list.d/sbt.list


cmd=\
"apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 \
--recv 2EE0EA64E40A89B84B2DF73499E82A75642AC823"


# Executa o comando para adicionar/atualizar a chave
generic_viewer                 \
    "$cmd"                     \
    "AptKey"                   \
    "Adding sbt keyserver..."


# Atualiza o sistema
generic_viewer               \
    "apt-get update"         \
    "AptGet Installer"       \
    "Updating the system..."


# Instala o sbt
generic_viewer                \
    "apt-get install -y sbt"  \
    "AptGet Installer"        \
    "Installing Scala sbt..."




# Instala/atualiza o python3
generic_viewer                   \
    "apt-get install -y python3" \
    "AptGet Installer"           \
    "Installing Python3..."


# Instala/atualiza o python-setuptools
generic_viewer                             \
    "apt-get install -y python-setuptools" \
    "AptGet Installer"                     \
    "Installing Python-setuptools..."


# Instala/atualiza o virtualenv
generic_viewer                             \
    "apt-get install -y python-virtualenv" \
    "AptGet Installer"                     \
    "Installing Python-virtualenv..."


# Instala/atualiza o pip
generic_viewer          \
    "easy_install pip"  \
    "Easy Intaller"     \
    "Installing Pip..."


# Instala/atualiza o nodejs
generic_viewer                  \
    "apt-get install -y nodejs" \
    "AptGet Installer"          \
    "Installing Nodejs..."


# Instala/atualiza o npm
generic_viewer               \
    "apt-get install -y npm" \
    "AptGet Installer"       \
    "Installing Npm..."


# Instala/atualiza o  bower
generic_viewer              \
    "npm install -g bower"  \
    "NPM Installer "        \
    "Installing Bower..."


# Copia a pasta do gsn para o diertório de instalação e renomeia para gsn-dev
cp -R "$downloadDir/gsn-release-2.0.1/gsn-gsn-release-2.0.1/" "${installDir}/gsndev"


# Configura o gsn
generic_viewer                                     \
    "gsn_conf "${installDir}/gsndev" "$javaHome" " \
    "Gsn Configurator"                             \
    "Configuring GSN..."


# Recupera o nome do grupo que o usuário pertence
usergrp=$(id -nG ${SUDO_USER} | cut -f1 -d' ')


# Muda o dono da pasta para o usuário
chown -R ${SUDO_USER} "${installDir}/gsndev"


# Muda o grupo da pasta para o grupo do usuário
chgrp -R $usergrp "${installDir}/gsndev"


# Volta o dialg para a configuração original
cp -p "$homeusr/.dialogrc.old" "$homeusr/.dialogrc" 2> /dev/null
rm "$homeusr/.dialogrc.old" 2> /dev/null


# Tela de encerramento
brief_box                                \
    "\ZbInstallation Finished\ZB"        \
    "Congratulations!"                   \
    "Installation process finished!"

clear
