# <img src="art/lpz-remote-icon-1024.png" width="64" align="center" alt=""> Lpz Remote (fork do iMoonlight para Linux/KDE)

Cliente Moonlight para iPhone pensado para controlar um PC **Linux com KDE Plasma** rodando
[Sunshine](https://github.com/LizardByte/Sunshine), de longe, pela Tailscale. É um fork do
[iMoonlight](https://github.com/ajhockey88/iMoonlight) (que por sua vez vem do
[Moonlight para iOS](https://github.com/moonlight-stream/moonlight-ios)), com a interface em
português e o visual Pantera (sangue e latão sobre preto).

## O que muda em relação ao iMoonlight

- **Teclado em português do Brasil.** Linha de acentos (´ ~ ^ `) que funcionam como teclas
  mortas (´ e depois a = á; ´ e depois c = ç), tecla ç, símbolos € £ º ª ° §. Tudo é enviado ao
  PC como sequência de teclas mortas do layout **EUA internacional**, que funciona em qualquer
  app do KDE (o caminho de texto UTF-8 do Sunshine falha em vários apps). As próprias ' " ` ~ ^
  saem como tecla + espaço. O teclado do iPhone (toque com três dedos) usa o mesmo caminho.
- **Autocorreção em português**, com 102 mil palavras e frequências do
  [wordfreq](https://github.com/rspeer/wordfreq): põe os acentos que faltam ("nao" vira "não",
  "voce" vira "você", "acao" vira "ação"), corrige um deslize de digitação e deixa em paz
  abreviações de conversa (vc, pq, tb, kkk). Toque na sugestão para manter o que digitou;
  apagar logo depois de uma correção a desfaz. Nos ajustes dá para voltar ao inglês.
- **Atalhos do KDE no lugar dos do Windows.** Teclas do PC: Alt+Tab, Super+W (visão geral),
  Super+D (área de trabalho), Super (menu), Alt+F4, Ctrl+Shift+Esc (monitor do sistema),
  PrtSc (Spectacle), Super+V (área de transferência). Gesto de três dedos para cima abre a
  visão geral, para baixo mostra a área de trabalho, para os lados troca de janela.
- **Monitores.** Botões Principal e Vertical trocam o monitor transmitido
  (Ctrl+Alt+Shift+F2 / F1 do Sunshine) e Cursor mostra ou esconde o ponteiro (Ctrl+Alt+Shift+N).
- **Zoom local da imagem.** Pince na imagem do PC para aproximar (até 5×) e arraste com dois
  dedos para mover; o selo "2,0× ✕" no canto volta à imagem inteira (ou toque duas vezes com
  dois dedos). Sem zoom, dois dedos na imagem continuam rolando o PC. A pinça no touchpad segue
  sendo o zoom do PC (Ctrl + roda do mouse).
- **Em pé:** um divisor arrastável entre a imagem e o touchpad muda o tamanho da imagem
  (toque duplo nele volta ao automático). Quando a imagem fica mais alta que a proporção da tela
  do PC, ela é ampliada para preencher a altura, e dá para movê-la com dois dedos.
- **Deitado:** a imagem ocupa a tela e uma faixa vertical à esquerda traz Teclado, Teclas,
  Touchpad, Zoom, Monitor, Vídeo, Ajustes e Sair. Cada função abre um painel feito para a tela
  deitada: teclado e teclas do PC embaixo, touchpad translúcido à direita (a imagem continua
  visível por baixo), zoom e monitores em cartões. Tocar na imagem fora dos painéis continua
  controlando o ponteiro, como no Moonlight.
- **Identidade própria:** nome Lpz Remote, ícone da pantera (`art/lpz-remote-icon.py` gera os
  tamanhos a partir de `art/lpz-remote-original.png`), cores do tema Pantera do Plasma e telas
  principais em português.
- **Cursor no centro ao conectar:** ao abrir a sessão o ponteiro vai para o centro do monitor
  transmitido, mesmo que tenha ficado no monitor vertical.

## Instalar no iPhone

1. Baixe `iMoonlight.ipa` na [última versão](../../releases/tag/latest) (ou no artefato
   `iMoonlight-ipa` de uma execução em [Actions](../../actions)).
2. Instale com [Sideloadly](https://sideloadly.io), AltStore ou SideStore usando o seu Apple ID.
   Com Apple ID gratuito o app precisa ser reinstalado a cada 7 dias.
3. No iPhone: Ajustes > Geral > VPN e Gerenciamento de Dispositivo, confie no seu Apple ID; no
   iOS 16 ou mais novo, ligue o Modo de Desenvolvedor.
4. Abra o Lpz Remote, toque em + e digite o IP do PC na Tailscale.

## Requisitos no PC

- Sunshine com captura KMS e `output_name` apontando para o conector do monitor principal.
- Layout de teclado **EUA internacional com teclas mortas** (`us` variante `intl`) para os
  acentos. Se o PC usar outro layout, desligue "PC com teclas mortas" nos ajustes do controle.

## Compilar

O GitHub Actions gera o `iMoonlight.ipa` sem assinatura a cada push
(`.github/workflows/build-ipa.yml`); pushes na `main` atualizam a versão `latest`.

## Créditos e licença

- Baseado no [iMoonlight](https://github.com/ajhockey88/iMoonlight) e no
  [moonlight-ios](https://github.com/moonlight-stream/moonlight-ios), GPLv3 (veja `LICENSE.txt`).
  Este fork também é GPLv3.
- Touchpad, teclado, teclas do PC e autocorreção em inglês vêm do
  [ThorPad](https://github.com/ajhockey88/ThorPad).
- Dicionário em inglês (`words.txt`): grafias do SCOWL e frequências do wordfreq (CC BY-SA 4.0);
  pares de palavras (`pairs.txt`): SymSpell (MIT) a partir do Google Books Ngram (CC BY 3.0).
- Dicionário em português (`words-pt.txt`): frequências do
  [wordfreq](https://github.com/rspeer/wordfreq), lista `pt` (dados CC BY-SA 4.0).
