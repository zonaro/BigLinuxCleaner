/* ============================================================
   BigLinuxCleaner — docs site
   i18n (pt / en / es) + interações (copiar, FAQ, reveal, menu)
   ============================================================ */
(function () {
    'use strict';

    /* ---------------- Dicionários de tradução ---------------- */
    const I18N = {
        pt: {
            'meta.title': 'BigLinuxCleaner — Limpeza e manutenção para o seu Big Linux',
            'meta.description': 'Script de manutenção para o Big Linux: remove pacotes órfãos, atalhos quebrados, resíduos do Flatpak e Snap e atualiza o menu do KDE Plasma. Instale em um comando.',
            'nav.recursos': 'O que faz',
            'nav.como': 'Como usar',
            'nav.instalacao': 'Instalação',
            'nav.faq': 'FAQ',
            'nav.github': 'Ver no GitHub',
            'nav.lang': 'Idioma / Language',
            'hero.badge': 'Big Linux · Comunidade',
            'hero.title': 'Mantenha seu <span class="grad">Big Linux</span> limpo, leve e rápido',
            'hero.lead': 'O <strong>BigLinuxCleaner</strong> é um script de manutenção que remove pacotes órfãos, atalhos quebrados e resíduos do Flatpak e Snap — e ainda atualiza o menu do KDE Plasma automaticamente. Tudo com um único comando.',
            'hero.cta1': 'Instalar agora',
            'hero.cta2': 'Executar uma vez',
            'hero.note': 'Requer Big Linux ou Arch + KDE Plasma ·',
            'hero.opensource': 'Código aberto (MIT)',
            'hero.term': 'bash — BigLinuxCleaner',
            'term.info1': 'Preparando permissões elevadas (sudo)...',
            'term.info2': 'Verificando atalhos órfãos do Flatpak por app ID...',
            'term.ok1': 'Limpeza do Flatpak concluída.',
            'term.info3': '--- Iniciando varredura de atalhos quebrados ---',
            'term.warn1': 'Atalho inválido detectado',
            'term.app': 'App:',
            'term.arquivo': 'Arquivo:',
            'term.ok2': 'Removido com sucesso.',
            'term.info4': 'Atualizando cache e menu do KDE Plasma...',
            'term.ok3': 'KRunner e cache do Plasma atualizados.',
            'term.resumo': '--- Resumo ---',
            'term.analisados': 'Arquivos .desktop analisados',
            'term.invalidos': 'Atalhos inválidos encontrados',
            'term.remocoes': 'Remoções concluídas',
            'term.fim': 'Processo finalizado.',
            'recursos.kicker': 'O que faz',
            'recursos.title': 'Tudo que seu sistema precisa, <span class="grad">automaticamente</span>',
            'recursos.sub': 'Um único script cuida da manutenção diária do seu Big Linux.',
            'f1.title': 'Remove pacotes órfãos',
            'f1.desc': 'Encontra e remove dependências do <code>pacman</code> que não são mais usadas por nenhum programa, liberando espaço em disco.',
            'f2.title': 'Limpa atalhos quebrados',
            'f2.desc': 'Varre os arquivos <code>.desktop</code> do sistema, do usuário, do Flatpak e do Snap e remove entradas que apontam para programas inexistentes.',
            'f3.title': 'Flatpak e Snap em dia',
            'f3.desc': 'Remove atalhos de apps desinstalados, limpa caches, elimina runtimes e revisões desabilitadas para recuperar espaço.',
            'f4.title': 'Menu KDE sempre atualizado',
            'f4.desc': 'Reconstrói o cache do KDE Plasma (<code>kbuildsycoca</code>, <code>krunner</code> e <code>plasmashell</code>) para que as mudanças apareçam na hora.',
            'f5.title': 'Atalho e ícone oficiais',
            'f5.desc': 'O instalador cria um atalho na Área de trabalho e/ou no Menu, com o ícone oficial, que roda o script direto do GitHub.',
            'f6.title': '100% código aberto',
            'f6.desc': 'Licença MIT, transparente e auditável. Leia o código-fonte no GitHub antes de executar — sem segredos.',
            'como.kicker': 'Como usar',
            'como.title': 'Execute em <span class="grad">um único comando</span>',
            'como.sub': 'Sem clonar repositório, sem instalar nada. Cole no terminal e pronto.',
            'como.cmd1.t': 'Rodar a limpeza agora (uma vez)',
            'como.cmd1.desc': 'Baixa o script mais recente do GitHub e executa direto no seu terminal.',
            'como.cmd1.coment': '# baixa e executa o cleaner.sh direto do GitHub',
            'botao.copiar': 'Copiar',
            'como.alert': '<span><strong>Atenção:</strong> sempre inspecione scripts antes de executá-los com privilégios. O script pede <code>sudo</code> apenas quando precisa alterar arquivos em <code>/usr</code> e <code>/var</code>. Você pode conferir o conteúdo completo em <a href="https://github.com/zonaro/BigLinuxCleaner/blob/main/cleaner.sh" target="_blank" rel="noopener">cleaner.sh</a>.</span>',
            'inst.kicker': 'Instalação',
            'inst.title': 'Crie um atalho com <span class="grad">um clique</span>',
            'inst.sub': 'Instale o BigLinuxCleaner na Área de trabalho e/ou no Menu de aplicativos, com o ícone oficial.',
            'inst.cmd1.t': 'Instalar como atalho (.desktop)',
            'inst.cmd1.desc': 'O atalho abre no seu terminal padrão, roda a limpeza e permanece aberto até você pressionar Enter.',
            'inst.cmd1.coment': '# instala o atalho + ícone (pergunta onde criar)',
            's1.title': 'Escolha onde criar',
            's1.desc': 'O instalador pergunta: <strong>1</strong> Área de trabalho, <strong>2</strong> Menu de aplicativos ou <strong>3</strong> Ambos.',
            's2.title': 'Ícone e atalho instalados',
            's2.desc': 'O ícone oficial vai para <code>~/.local/share/icons/</code> e o atalho <code>.desktop</code> é criado com o comando do cleaner.',
            's3.title': 'Pronto! É só clicar',
            's3.desc': 'Cada clique no atalho executa a limpeza completa e atualiza o menu do KDE Plasma automaticamente.',
            'inst.cmd2.t': 'Remover o atalho depois',
            'inst.cmd2.desc': 'Se quiser desinstalar o atalho e o ícone, rode o comando abaixo — ele baixa o script do GitHub novamente e remove tudo com a flag <code>--uninstall</code>.',
            'faq.kicker': 'Perguntas frequentes',
            'faq.title': 'Ficou com <span class="grad">dúvidas?</span>',
            'faq.sub': 'As respostas para as perguntas mais comuns sobre o script.',
            'faq.1.q': 'O que o script faz exatamente?',
            'faq.1.a': 'O <code>cleaner.sh</code> executa cinco tarefas: remove pacotes órfãos do <code>pacman</code>; varre e remove atalhos <code>.desktop</code> quebrados (sistema, usuário, Flatpak e Snap); remove atalhos de apps Flatpak/Snap desinstalados; limpa caches e resíduos do Flatpak e Snap; e atualiza o menu e o cache do KDE Plasma (<code>kbuildsycoca</code>, <code>krunner</code>, <code>plasmashell</code>).',
            'faq.2.q': 'Preciso instalar o Git ou clonar o repositório?',
            'faq.2.a': 'Não. O script roda direto do GitHub via <code>curl</code>, sem clonar nada. O único pré-requisito é ter o <code>curl</code> instalado (presente no Big Linux por padrão).',
            'faq.3.q': 'O script é seguro? Ele pede sudo?',
            'faq.3.a': 'O código é aberto (MIT) e pode ser inspecionado no GitHub antes de rodar. Ele solicita <code>sudo</code> apenas quando precisa alterar arquivos em <code>/usr</code> e <code>/var</code> (por exemplo, atalhos de sistema e cache global). Recomendamos sempre revisar scripts antes de executá-los com privilégios.',
            'faq.4.q': 'Funciona em outras distros baseadas em Arch?',
            'faq.4.a': 'Sim. O script foi criado para o Big Linux, mas funciona em qualquer distro baseada em Arch que use <code>pacman</code> e KDE Plasma. Se a ferramenta não existir (Flatpak, Snap etc.), essa parte é ignorada sem erro.',
            'faq.5.q': 'E se eu não tiver Flatpak ou Snap instalados?',
            'faq.5.a': 'Sem problema. O script detecta a ausência dessas ferramentas e pula as etapas correspondentes, exibindo um aviso <code>[WARN]</code> — nada é quebrado.',
            'faq.6.q': 'Como desinstalo o atalho depois?',
            'faq.6.a': 'Execute o comando <code>curl -fsSL https://raw.githubusercontent.com/zonaro/BigLinuxCleaner/main/install.sh | bash -s -- --uninstall</code> (ou baixe o <code>install.sh</code> e rode <code>./install.sh --uninstall</code>). Ele remove o atalho <code>.desktop</code> e o ícone instalado, tanto do Menu quanto da Área de trabalho.',
            'faq.7.q': 'Onde encontro o código e como contribuo?',
            'faq.7.a': 'Tudo está no repositório <a href="https://github.com/zonaro/BigLinuxCleaner" target="_blank" rel="noopener">zonaro/BigLinuxCleaner</a>. Issues, sugestões e pull requests são muito bem-vindos!',
            'footer.tagline': 'Seja <span class="grad">Big</span>, use o BigLinux!',
            'footer.sub': 'Um projeto independente da comunidade para manter o seu sistema limpo e rápido.',
            'footer.github': 'Ver no GitHub',
            'footer.executar': 'Executar agora',
            'footer.disclaimer': 'Este projeto é <strong>independente</strong> e não possui afiliação, endosso ou patrocínio do projeto BigLinux. “Big Linux” é uma marca de seus respectivos proprietários.',
            'footer.col1.p': 'Script de limpeza e manutenção para o Big Linux: órfãos, atalhos quebrados e cache do KDE — em um comando.',
            'footer.col2.h': 'Navegação',
            'footer.col3.h': 'Recursos',
            'footer.col4.h': 'Comunidade',
            'footer.issues': 'Reportar problema',
            'footer.contribuir': 'Contribuir',
            'footer.license': 'BigLinuxCleaner · Licença MIT',
            'footer.made': 'Desenvolvido para a comunidade Big Linux'
        },

        en: {
            'meta.title': 'BigLinuxCleaner — Cleanup and maintenance for your Big Linux',
            'meta.description': 'Maintenance script for Big Linux: removes orphan packages, broken shortcuts, Flatpak and Snap leftovers and refreshes the KDE Plasma menu. Install with one command.',
            'nav.recursos': 'What it does',
            'nav.como': 'How to use',
            'nav.instalacao': 'Install',
            'nav.faq': 'FAQ',
            'nav.github': 'View on GitHub',
            'nav.lang': 'Language',
            'hero.badge': 'Big Linux · Community',
            'hero.title': 'Keep your <span class="grad">Big Linux</span> clean, light and fast',
            'hero.lead': '<strong>BigLinuxCleaner</strong> is a maintenance script that removes orphan packages, broken shortcuts and Flatpak and Snap leftovers — and automatically refreshes the KDE Plasma menu. All with a single command.',
            'hero.cta1': 'Install now',
            'hero.cta2': 'Run once',
            'hero.note': 'Requires Big Linux or Arch + KDE Plasma ·',
            'hero.opensource': 'Open source (MIT)',
            'hero.term': 'bash — BigLinuxCleaner',
            'term.info1': 'Preparing elevated permissions (sudo)...',
            'term.info2': 'Checking Flatpak orphan shortcuts by app ID...',
            'term.ok1': 'Flatpak cleanup finished.',
            'term.info3': '--- Starting broken shortcut scan ---',
            'term.warn1': 'Invalid shortcut detected',
            'term.app': 'App:',
            'term.arquivo': 'File:',
            'term.ok2': 'Removed successfully.',
            'term.info4': 'Refreshing KDE Plasma cache and menu...',
            'term.ok3': 'KRunner and Plasma cache updated.',
            'term.resumo': '--- Summary ---',
            'term.analisados': '.desktop files analyzed',
            'term.invalidos': 'Invalid shortcuts found',
            'term.remocoes': 'Removals completed',
            'term.fim': 'Process finished.',
            'recursos.kicker': 'What it does',
            'recursos.title': 'Everything your system needs, <span class="grad">automatically</span>',
            'recursos.sub': 'A single script takes care of your Big Linux daily maintenance.',
            'f1.title': 'Removes orphan packages',
            'f1.desc': 'Finds and removes <code>pacman</code> dependencies that are no longer used by any program, freeing up disk space.',
            'f2.title': 'Cleans broken shortcuts',
            'f2.desc': 'Scans <code>.desktop</code> files from system, user, Flatpak and Snap and removes entries pointing to non-existent programs.',
            'f3.title': 'Flatpak and Snap up to date',
            'f3.desc': 'Removes shortcuts from uninstalled apps, cleans caches and removes disabled runtimes and revisions to reclaim space.',
            'f4.title': 'KDE menu always updated',
            'f4.desc': 'Rebuilds the KDE Plasma cache (<code>kbuildsycoca</code>, <code>krunner</code> and <code>plasmashell</code>) so changes show up right away.',
            'f5.title': 'Official shortcut and icon',
            'f5.desc': 'The installer creates a shortcut on the Desktop and/or in the Menu, with the official icon, that runs the script straight from GitHub.',
            'f6.title': '100% open source',
            'f6.desc': 'MIT license, transparent and auditable. Read the source code on GitHub before running — no secrets.',
            'como.kicker': 'How to use',
            'como.title': 'Run with <span class="grad">a single command</span>',
            'como.sub': 'No cloning, no installing anything. Paste into the terminal and you are done.',
            'como.cmd1.t': 'Run the cleanup now (one time)',
            'como.cmd1.desc': 'Downloads the latest script from GitHub and runs it directly in your terminal.',
            'como.cmd1.coment': '# downloads and runs cleaner.sh straight from GitHub',
            'botao.copiar': 'Copy',
            'como.alert': '<span><strong>Heads up:</strong> always inspect scripts before running them with privileges. The script only asks for <code>sudo</code> when it needs to change files in <code>/usr</code> and <code>/var</code>. You can check the full contents at <a href="https://github.com/zonaro/BigLinuxCleaner/blob/main/cleaner.sh" target="_blank" rel="noopener">cleaner.sh</a>.</span>',
            'inst.kicker': 'Install',
            'inst.title': 'Create a shortcut with <span class="grad">one click</span>',
            'inst.sub': 'Install BigLinuxCleaner on the Desktop and/or in the application menu, with the official icon.',
            'inst.cmd1.t': 'Install as a shortcut (.desktop)',
            'inst.cmd1.desc': 'The shortcut opens in your default terminal, runs the cleanup and stays open until you press Enter.',
            'inst.cmd1.coment': '# installs the shortcut + icon (asks where to create)',
            's1.title': 'Choose where to create',
            's1.desc': 'The installer asks: <strong>1</strong> Desktop, <strong>2</strong> Application menu or <strong>3</strong> Both.',
            's2.title': 'Icon and shortcut installed',
            's2.desc': 'The official icon goes to <code>~/.local/share/icons/</code> and the <code>.desktop</code> shortcut is created with the cleaner command.',
            's3.title': 'Done! Just click',
            's3.desc': 'Every click on the shortcut runs the full cleanup and refreshes the KDE Plasma menu automatically.',
            'inst.cmd2.t': 'Remove the shortcut later',
            'inst.cmd2.desc': 'If you want to uninstall the shortcut and icon, run the command below — it downloads the script from GitHub again and removes everything with the <code>--uninstall</code> flag.',
            'faq.kicker': 'Frequently asked questions',
            'faq.title': 'Got <span class="grad">questions?</span>',
            'faq.sub': 'Answers to the most common questions about the script.',
            'faq.1.q': 'What does the script do exactly?',
            'faq.1.a': '<code>cleaner.sh</code> performs five tasks: removes orphan <code>pacman</code> packages; scans and removes broken <code>.desktop</code> shortcuts (system, user, Flatpak and Snap); removes shortcuts from uninstalled Flatpak/Snap apps; cleans Flatpak and Snap caches and leftovers; and refreshes the KDE Plasma menu and cache (<code>kbuildsycoca</code>, <code>krunner</code>, <code>plasmashell</code>).',
            'faq.2.q': 'Do I need to install Git or clone the repository?',
            'faq.2.a': 'No. The script runs straight from GitHub via <code>curl</code>, without cloning anything. The only requirement is having <code>curl</code> installed (present on Big Linux by default).',
            'faq.3.q': 'Is the script safe? Does it ask for sudo?',
            'faq.3.a': 'The code is open source (MIT) and can be inspected on GitHub before running. It only asks for <code>sudo</code> when it needs to change files in <code>/usr</code> and <code>/var</code> (e.g., system shortcuts and global cache). We always recommend reviewing scripts before running them with privileges.',
            'faq.4.q': 'Does it work on other Arch-based distros?',
            'faq.4.a': 'Yes. The script was built for Big Linux, but works on any Arch-based distro using <code>pacman</code> and KDE Plasma. If a tool is missing (Flatpak, Snap, etc.), that part is skipped without errors.',
            'faq.5.q': 'What if I do not have Flatpak or Snap installed?',
            'faq.5.a': 'No problem. The script detects when those tools are missing and skips the related steps, showing a <code>[WARN]</code> notice — nothing breaks.',
            'faq.6.q': 'How do I uninstall the shortcut later?',
            'faq.6.a': 'Run the command <code>curl -fsSL https://raw.githubusercontent.com/zonaro/BigLinuxCleaner/main/install.sh | bash -s -- --uninstall</code> (or download <code>install.sh</code> and run <code>./install.sh --uninstall</code>). It removes the <code>.desktop</code> shortcut and the installed icon, from both the Menu and the Desktop.',
            'faq.7.q': 'Where can I find the code and how do I contribute?',
            'faq.7.a': 'Everything is in the <a href="https://github.com/zonaro/BigLinuxCleaner" target="_blank" rel="noopener">zonaro/BigLinuxCleaner</a> repository. Issues, suggestions and pull requests are very welcome!',
            'footer.tagline': 'Be <span class="grad">Big</span>, use BigLinux!',
            'footer.sub': 'An independent community project to keep your system clean and fast.',
            'footer.github': 'View on GitHub',
            'footer.executar': 'Run now',
            'footer.disclaimer': 'This project is <strong>independent</strong> and has no affiliation, endorsement or sponsorship from the BigLinux project. "Big Linux" is a trademark of its respective owners.',
            'footer.col1.p': 'Cleanup and maintenance script for Big Linux: orphans, broken shortcuts and KDE cache — in one command.',
            'footer.col2.h': 'Navigation',
            'footer.col3.h': 'Resources',
            'footer.col4.h': 'Community',
            'footer.issues': 'Report an issue',
            'footer.contribuir': 'Contribute',
            'footer.license': 'BigLinuxCleaner · MIT License',
            'footer.made': 'Made for the Big Linux community'
        },

        es: {
            'meta.title': 'BigLinuxCleaner — Limpieza y mantenimiento para tu Big Linux',
            'meta.description': 'Script de mantenimiento para Big Linux: elimina paquetes huérfanos, accesos directos rotos, residuos de Flatpak y Snap y actualiza el menú de KDE Plasma. Instala con un comando.',
            'nav.recursos': 'Qué hace',
            'nav.como': 'Cómo usar',
            'nav.instalacao': 'Instalación',
            'nav.faq': 'FAQ',
            'nav.github': 'Ver en GitHub',
            'nav.lang': 'Idioma / Language',
            'hero.badge': 'Big Linux · Comunidad',
            'hero.title': 'Mantén tu <span class="grad">Big Linux</span> limpio, ligero y rápido',
            'hero.lead': '<strong>BigLinuxCleaner</strong> es un script de mantenimiento que elimina paquetes huérfanos, accesos directos rotos y residuos de Flatpak y Snap — y además actualiza el menú de KDE Plasma automáticamente. Todo con un solo comando.',
            'hero.cta1': 'Instalar ahora',
            'hero.cta2': 'Ejecutar una vez',
            'hero.note': 'Requiere Big Linux o Arch + KDE Plasma ·',
            'hero.opensource': 'Código abierto (MIT)',
            'hero.term': 'bash — BigLinuxCleaner',
            'term.info1': 'Preparando permisos elevados (sudo)...',
            'term.info2': 'Comprobando accesos directos huérfanos de Flatpak por app ID...',
            'term.ok1': 'Limpieza de Flatpak finalizada.',
            'term.info3': '--- Iniciando escaneo de accesos directos rotos ---',
            'term.warn1': 'Acceso directo no válido detectado',
            'term.app': 'App:',
            'term.arquivo': 'Archivo:',
            'term.ok2': 'Eliminado correctamente.',
            'term.info4': 'Actualizando caché y menú de KDE Plasma...',
            'term.ok3': 'KRunner y caché de Plasma actualizados.',
            'term.resumo': '--- Resumen ---',
            'term.analisados': 'Archivos .desktop analizados',
            'term.invalidos': 'Accesos directos no válidos encontrados',
            'term.remocoes': 'Eliminaciones completadas',
            'term.fim': 'Proceso finalizado.',
            'recursos.kicker': 'Qué hace',
            'recursos.title': 'Todo lo que tu sistema necesita, <span class="grad">automáticamente</span>',
            'recursos.sub': 'Un solo script se encarga del mantenimiento diario de tu Big Linux.',
            'f1.title': 'Elimina paquetes huérfanos',
            'f1.desc': 'Encuentra y elimina dependencias de <code>pacman</code> que ya no usa ningún programa, liberando espacio en disco.',
            'f2.title': 'Limpia accesos directos rotos',
            'f2.desc': 'Escanea los archivos <code>.desktop</code> del sistema, del usuario, de Flatpak y de Snap y elimina entradas que apuntan a programas inexistentes.',
            'f3.title': 'Flatpak y Snap al día',
            'f3.desc': 'Elimina accesos directos de apps desinstaladas, limpia cachés y elimina runtimes y revisiones deshabilitadas para recuperar espacio.',
            'f4.title': 'Menú KDE siempre actualizado',
            'f4.desc': 'Reconstruye la caché de KDE Plasma (<code>kbuildsycoca</code>, <code>krunner</code> y <code>plasmashell</code>) para que los cambios aparezcan al instante.',
            'f5.title': 'Acceso directo e icono oficiales',
            'f5.desc': 'El instalador crea un acceso directo en el Escritorio y/o en el Menú, con el icono oficial, que ejecuta el script directamente desde GitHub.',
            'f6.title': '100% código abierto',
            'f6.desc': 'Licencia MIT, transparente y auditable. Lee el código fuente en GitHub antes de ejecutarlo — sin secretos.',
            'como.kicker': 'Cómo usar',
            'como.title': 'Ejecuta con <span class="grad">un solo comando</span>',
            'como.sub': 'Sin clonar repositorios, sin instalar nada. Pega en la terminal y listo.',
            'como.cmd1.t': 'Ejecutar la limpieza ahora (una vez)',
            'como.cmd1.desc': 'Descarga el script más reciente desde GitHub y lo ejecuta directamente en tu terminal.',
            'como.cmd1.coment': '# descarga y ejecuta cleaner.sh directamente desde GitHub',
            'botao.copiar': 'Copiar',
            'como.alert': '<span><strong>Atención:</strong> inspecciona siempre los scripts antes de ejecutarlos con privilegios. El script solo pide <code>sudo</code> cuando necesita modificar archivos en <code>/usr</code> y <code>/var</code>. Puedes revisar el contenido completo en <a href="https://github.com/zonaro/BigLinuxCleaner/blob/main/cleaner.sh" target="_blank" rel="noopener">cleaner.sh</a>.</span>',
            'inst.kicker': 'Instalación',
            'inst.title': 'Crea un acceso directo con <span class="grad">un clic</span>',
            'inst.sub': 'Instala BigLinuxCleaner en el Escritorio y/o en el menú de aplicaciones, con el icono oficial.',
            'inst.cmd1.t': 'Instalar como acceso directo (.desktop)',
            'inst.cmd1.desc': 'El acceso directo abre en tu terminal predeterminada, ejecuta la limpieza y permanece abierto hasta que pulses Enter.',
            'inst.cmd1.coment': '# instala el acceso directo + icono (pregunta dónde crear)',
            's1.title': 'Elige dónde crear',
            's1.desc': 'El instalador pregunta: <strong>1</strong> Escritorio, <strong>2</strong> Menú de aplicaciones o <strong>3</strong> Ambos.',
            's2.title': 'Icono y acceso directo instalados',
            's2.desc': 'El icono oficial va a <code>~/.local/share/icons/</code> y el acceso directo <code>.desktop</code> se crea con el comando del cleaner.',
            's3.title': '¡Listo! Solo haz clic',
            's3.desc': 'Cada clic en el acceso directo ejecuta la limpieza completa y actualiza el menú de KDE Plasma automáticamente.',
            'inst.cmd2.t': 'Eliminar el acceso directo después',
            'inst.cmd2.desc': 'Si quieres desinstalar el acceso directo y el icono, ejecuta el comando de abajo — descarga el script de GitHub de nuevo y lo elimina todo con la bandera <code>--uninstall</code>.',
            'faq.kicker': 'Preguntas frecuentes',
            'faq.title': '¿Tienes <span class="grad">dudas?</span>',
            'faq.sub': 'Las respuestas a las preguntas más comunes sobre el script.',
            'faq.1.q': '¿Qué hace exactamente el script?',
            'faq.1.a': '<code>cleaner.sh</code> realiza cinco tareas: elimina paquetes huérfanos de <code>pacman</code>; escanea y elimina accesos directos <code>.desktop</code> rotos (sistema, usuario, Flatpak y Snap); elimina accesos directos de apps Flatpak/Snap desinstaladas; limpia cachés y residuos de Flatpak y Snap; y actualiza el menú y la caché de KDE Plasma (<code>kbuildsycoca</code>, <code>krunner</code>, <code>plasmashell</code>).',
            'faq.2.q': '¿Necesito instalar Git o clonar el repositorio?',
            'faq.2.a': 'No. El script se ejecuta directamente desde GitHub mediante <code>curl</code>, sin clonar nada. El único requisito es tener <code>curl</code> instalado (presente en Big Linux por defecto).',
            'faq.3.q': '¿El script es seguro? ¿Pide sudo?',
            'faq.3.a': 'El código es abierto (MIT) y se puede inspeccionar en GitHub antes de ejecutarlo. Solo pide <code>sudo</code> cuando necesita modificar archivos en <code>/usr</code> y <code>/var</code> (por ejemplo, accesos directos del sistema y caché global). Recomendamos revisar siempre los scripts antes de ejecutarlos con privilegios.',
            'faq.4.q': '¿Funciona en otras distros basadas en Arch?',
            'faq.4.a': 'Sí. El script fue creado para Big Linux, pero funciona en cualquier distro basada en Arch que use <code>pacman</code> y KDE Plasma. Si la herramienta no existe (Flatpak, Snap, etc.), esa parte se omite sin errores.',
            'faq.5.q': '¿Y si no tengo Flatpak o Snap instalados?',
            'faq.5.a': 'Sin problema. El script detecta la ausencia de esas herramientas y omite los pasos correspondientes, mostrando un aviso <code>[WARN]</code> — nada se rompe.',
            'faq.6.q': '¿Cómo desinstalo el acceso directo después?',
            'faq.6.a': 'Ejecuta el comando <code>curl -fsSL https://raw.githubusercontent.com/zonaro/BigLinuxCleaner/main/install.sh | bash -s -- --uninstall</code> (o descarga <code>install.sh</code> y ejecuta <code>./install.sh --uninstall</code>). Elimina el acceso directo <code>.desktop</code> y el icono instalado, tanto del Menú como del Escritorio.',
            'faq.7.q': '¿Dónde encuentro el código y cómo contribuyo?',
            'faq.7.a': 'Todo está en el repositorio <a href="https://github.com/zonaro/BigLinuxCleaner" target="_blank" rel="noopener">zonaro/BigLinuxCleaner</a>. ¡Issues, sugerencias y pull requests son muy bienvenidos!',
            'footer.tagline': '¡Sé <span class="grad">Big</span>, usa BigLinux!',
            'footer.sub': 'Un proyecto independiente de la comunidad para mantener tu sistema limpio y rápido.',
            'footer.github': 'Ver en GitHub',
            'footer.executar': 'Ejecutar ahora',
            'footer.disclaimer': 'Este proyecto es <strong>independiente</strong> y no tiene afiliación, respaldo ni patrocinio del proyecto BigLinux. "Big Linux" es una marca de sus respectivos propietarios.',
            'footer.col1.p': 'Script de limpieza y mantenimiento para Big Linux: huérfanos, accesos directos rotos y caché de KDE — en un comando.',
            'footer.col2.h': 'Navegación',
            'footer.col3.h': 'Recursos',
            'footer.col4.h': 'Comunidad',
            'footer.issues': 'Reportar un problema',
            'footer.contribuir': 'Contribuir',
            'footer.license': 'BigLinuxCleaner · Licencia MIT',
            'footer.made': 'Hecho para la comunidad Big Linux'
        }
    };

    const LANGS = ['pt', 'en', 'es'];
    const STORAGE_KEY = 'blc-lang';

    /* ---------------- Detecção de idioma ---------------- */
    function detectLang() {
        try {
            const saved = localStorage.getItem(STORAGE_KEY);
            if (saved && LANGS.indexOf(saved) !== -1) return saved;
        } catch (e) { /* armazenamento indisponível */ }

        const nav = (navigator.language || navigator.userLanguage || 'en').toLowerCase();
        if (nav.indexOf('pt') === 0) return 'pt';
        if (nav.indexOf('es') === 0) return 'es';
        return 'en';
    }

    /* ---------------- Aplicar idioma ---------------- */
    function applyLang(lang) {
        const dict = I18N[lang] || I18N.en;
        document.documentElement.lang = lang;

        // título e descrição meta
        if (dict['meta.title']) document.title = dict['meta.title'];
        const meta = document.querySelector('meta[name="description"]');
        if (meta && dict['meta.description']) meta.setAttribute('content', dict['meta.description']);

        // texto via innerHTML (permite HTML como <span class="grad">)
        document.querySelectorAll('[data-i18n]').forEach(function (el) {
            const key = el.getAttribute('data-i18n');
            if (dict[key]) el.innerHTML = dict[key];
        });

        // atributos de acessibilidade
        document.querySelectorAll('[data-i18n-aria-label]').forEach(function (el) {
            const key = el.getAttribute('data-i18n-aria-label');
            if (dict[key]) el.setAttribute('aria-label', dict[key]);
        });

        // seletor sincronizado
        const select = document.getElementById('lang-select');
        if (select) select.value = lang;
    }

    /* ---------------- Seletor de idioma ---------------- */
    function setupLang() {
        const select = document.getElementById('lang-select');
        if (!select) return;
        select.addEventListener('change', function () {
            const lang = select.value;
            try { localStorage.setItem(STORAGE_KEY, lang); } catch (e) { /* sem armazenamento */ }
            applyLang(lang);
        });
    }

    /* ---------------- Botões copiar ---------------- */
    function setupCopyButtons() {
        document.querySelectorAll('.copy').forEach(function (btn) {
            btn.addEventListener('click', function () {
                const code = btn.getAttribute('data-code') || '';
                function done() {
                    const original = btn.textContent;
                    btn.textContent = '✓';
                    btn.classList.add('copied');
                    setTimeout(function () {
                        btn.textContent = original;
                        btn.classList.remove('copied');
                    }, 1600);
                }
                if (navigator.clipboard && navigator.clipboard.writeText) {
                    navigator.clipboard.writeText(code).then(done, function () {
                        fallbackCopy(code, done);
                    });
                } else {
                    fallbackCopy(code, done);
                }
            });
        });
    }

    function fallbackCopy(text, done) {
        const ta = document.createElement('textarea');
        ta.value = text;
        ta.style.position = 'fixed';
        ta.style.opacity = '0';
        document.body.appendChild(ta);
        ta.select();
        try { document.execCommand('copy'); } catch (e) { /* ignore */ }
        document.body.removeChild(ta);
        done();
    }

    /* ---------------- FAQ (apenas um aberto) ---------------- */
    function setupFaq() {
        const items = document.querySelectorAll('.faq__item');
        items.forEach(function (item) {
            item.addEventListener('toggle', function () {
                if (item.open) {
                    items.forEach(function (other) {
                        if (other !== item) other.open = false;
                    });
                }
            });
        });
    }

    /* ---------------- Reveal on scroll ---------------- */
    function setupReveal() {
        const els = document.querySelectorAll('.reveal');
        if (!('IntersectionObserver' in window)) {
            els.forEach(function (el) { el.classList.add('is-visible'); });
            return;
        }
        const io = new IntersectionObserver(function (entries) {
            entries.forEach(function (entry) {
                if (entry.isIntersecting) {
                    entry.target.classList.add('is-visible');
                    io.unobserve(entry.target);
                }
            });
        }, { threshold: 0.12 });
        els.forEach(function (el) { io.observe(el); });
    }

    /* ---------------- Menu mobile ---------------- */
    function setupMenu() {
        const toggle = document.querySelector('.nav__toggle');
        const links = document.getElementById('nav-links');
        if (!toggle || !links) return;
        toggle.addEventListener('click', function () {
            const isOpen = links.classList.toggle('is-open');
            toggle.classList.toggle('is-open', isOpen);
            toggle.setAttribute('aria-expanded', isOpen ? 'true' : 'false');
        });
        links.querySelectorAll('a').forEach(function (a) {
            a.addEventListener('click', function () {
                links.classList.remove('is-open');
                toggle.classList.remove('is-open');
                toggle.setAttribute('aria-expanded', 'false');
            });
        });
    }

    /* ---------------- Ano dinâmico ---------------- */
    function setupYear() {
        const els = document.querySelectorAll('.js-year');
        els.forEach(function (el) { el.textContent = String(new Date().getFullYear()); });
    }

    /* ---------------- Inicialização ---------------- */
    document.addEventListener('DOMContentLoaded', function () {
        applyLang(detectLang());
        setupLang();
        setupCopyButtons();
        setupFaq();
        setupReveal();
        setupMenu();
        setupYear();
    });
})();
