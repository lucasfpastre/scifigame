# 🚀 Kobayashi Maru: Protocolo 104

> *"O teste da Kobayashi Maru não avalia sua capacidade de vencer, mas sim como você comanda diante do inevitável."*

Um simulador tático de ficção científica com elementos de **Roguelite** e estética retrô de **Terminal CRT de Fósforo Verde e ASCII**, desenvolvido em **Godot 4**. 

Inspirado no lendário teste de comando da Frota Estelar de *Star Trek*, o jogador assume a capitania de uma nave da Federação que recebe uma transmissão de emergência do cargueiro civil **Kobayashi Maru**, avariado no interior da perigosa **Zona Neutra**.

---

## 📸 Identidade Visual & Atmosfera

* **Terminal CRT Autêntico:** Shader de pós-processamento com curvatura analógica de tubo, linhas de varredura (*scanlines*), brilho de fósforo verde monocromático, vinheta e tremulação catódica.
* **Radar Tático em ASCII Puro:** Grade espacial 2D de alta legibilidade com anéis de alcance discretos, vetores de deslocamento e rastreamento de contatos com codificação por cores e telemetria em tempo real:
  * `[@]` **Nave do Jogador** (Ciano)
  * `[K]` **S.S. Kobayashi Maru** (Amarelo de Emergência)
  * `[V]` **Cruzadores de Batalha Hostis** (Vermelho de Alerta)
  * `[*]` **Campo de Destroços e Minas Espaciais** (Oliva / Neutro)
* **Áudio Procedural Chiptune/Retro:** Efeitos sonoros gerados dinamicamente via código (`AudioStreamGenerator`) para cliques mecânicos de teclado, digitação teletipo, sirenes de Alerta Vermelho e disparos de laser, sem necessidade de arquivos externos.

---

## ⚙️ Mecânicas Principais

### 1. Gerenciamento do Reator (*Power Grid*)
A energia do reator da nave é limitada (10 MW base). O Capitão precisa balancear a energia dinamicamente entre os módulos através de uma interface tátil (otimizada para **Mouse** no Desktop e **Toque** no Android):
* **MOTORES:** Controla a capacidade de manobra, velocidade de aproximação ao alvo e taxa de evasão contra torpedos inimigos.
* **ESCUDOS:** Taxa de regeneração e integridade do campo de força defletor.
* **SENSORES:** Alcance de varredura e resolução de telemetria (sensores baixos exibem apenas assinaturas vagas `?`).
* **LASERS:** Tempo de recarga dos capacitores de feixes e dano concentrado.
* **SUPORTE DE VIDA:** Pode ser temporariamente desligado em emergências críticas para redirecionar potência extra para armas ou escudos.

### 2. Relação e Moral da Tripulação (*Crew Intercom*)
A nave é operada por quatro oficiais com níveis individuais de **Confiança** e **Estresse**, que reagem dinamicamente no rádio de bordo:
* **Ten. Vega (Piloto / Navegação):** Com alta confiança, mantém a nave manobrável no leme manual mesmo se os motores forem drenados a zero.
* **Ch. O'Malley (Engenharia-Chefe):** Coordena equipes de reparos de casco e avisa quando o reator está sob estresse térmico.
* **Dra. T'Serra (Ciências):** Decifra assinaturas de camuflagem e intercepta transmissões alienígenas.
* **Ten. Thorne (Tático / Armamento):** Opera as baterias de feixes e trava mira em múltiplos alvos sob pressão.

---

## 🎯 Plataformas Suportadas

O projeto foi projetado com interface adaptável para:
- 🖥️ **Windows**
- 🐧 **Linux**
- 📱 **Android** (suporte nativo a telas touch)

---

## 🛠️ Tecnologias Utilizadas

* **Engine:** [Godot Engine 4.x](https://godotengine.org/) (GL Compatibility / D3D12)
* **Linguagem:** GDScript
* **Shaders:** Godot CanvasItem Shader Language
* **Fonte:** Monospace TTF empacotada localmente para consistência multiplataforma

---

## 🚀 Como Executar o Projeto

1. Baixe ou clone este repositório:
   ```bash
   git clone https://github.com/lucasfpastre/scifigame.git
   ```
2. Abra o **Godot 4.3+** (ou superior).
3. Na janela do Gerenciador de Projetos do Godot, clique em **Importar** e selecione o arquivo `project.godot`.
4. Clique em **Editar e Rodar** ou pressione **F5** para iniciar a simulação!

---

## 🗺️ Roadmap de Desenvolvimento

- [x] Shader CRT de Fósforo Verde e Tema Retrô de Terminal.
- [x] Radar Tático ASCII com telemetria colorida e alinhamento monoespaçado.
- [x] Sistema de Reator e Distribuição de Energia (*Power Grid*).
- [x] Sistema de Tripulação com bônus de eficiência e reações no rádio.
- [x] Síntese procedural de efeitos sonoros retrô.
- [ ] Sistema de Meta-Progressão Roguelite (Desbloqueio de novas naves e protocolos da Academia entre as *runs*).
- [ ] Eventos narrativos aleatórios e diálogos procedurais com naves civis e patrulhas hostis.
- [ ] Rota oculta investigativa inspirada em James T. Kirk (hackear os parâmetros da simulação).

---

## 📄 Licença

Distribuído sob a licença MIT. Consulte `LICENSE` para mais detalhes.
