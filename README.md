# 🚀 Protocolo Alcântara: O Incidente do Baependi

> *"O Protocolo Baependi não avalia sua capacidade de vencer o inevitável, mas sim a fibra moral e a coragem de um Capitão diante do sacrifício."*

Um simulador tático de ficção científica espacial brasileira com elementos de **Roguelite** e estética retrô de **Terminal CRT de Fósforo Verde e ASCII**, desenvolvido em **Godot 4**. 

Inspirado nos clássicos dilemas de comando da ficção científica e na bravura histórica naval brasileira, o jogador assume o comando da nave estelar **CCS João Cândido** (homenagem ao lendário *Almirante Negro*, líder da Revolta da Chibata que lutou pela dignidade dos marinheiros). Sua missão de treinamento: responder a um pedido desesperado de socorro do **Cargueiro Civil Baependi**, torpedeado e avariado na perigosa **Zona Desmilitarizada de Abrolhos**, cercado por cruzadores da **Falange Autocrata (Fascistóides)**.

---

## 🇧🇷 Identidade & Ambientação (Sci-Fi Nacional)

* **Belonave de Comando:** **CCS João Cândido // NX-900** (*Coalizão Cruzeiro do Sul*).
* **Nave em Perigo:** **Cargueiro Civil Baependi** (homenagem ao navio mercante brasileiro torpedeado por forças fascistas na Segunda Guerra Mundial).
* **Os Antagonistas:** **A Falange Autocrata** — belonaves de combate com doutrina militarista, expansionista e impiedosa.
* **A Tripulação:**
  * **Tenente Moreira** (Piloto / Navegação)
  * **Engenheiro Barbosa** (Engenharia-Chefe & Reator)
  * **Dra. Dandara** (Ciências & Análise Espectral)
  * **Tenente Araripe** (Tático & Baterias de Defesa)

---

## 📸 Identidade Visual & Áudio

* **Terminal CRT Autêntico:** Shader de pós-processamento com curvatura de tela analógica, linhas de varredura (*scanlines*), efeito de persistência de fósforo verde monocromático, vinheta e oscilação catódica.
* **Radar Tático em ASCII Puro:** Grade espacial 2D de alta legibilidade com anéis de alcance e retículo em fósforo escuro, destacando alvos e projéteis em tempo real:
  * `[@]` **CCS João Cândido** (Ciano Brilhante)
  * `[B]` **Cargueiro Civil Baependi** (Amarelo de Emergência)
  * `[V]` **Cruzadores Fascistas Classe Falange** (Vermelho de Alerta)
  * `[!]` **Torpedos em Curso de Colisão** (Vermelho Intenso Piscante)
  * `[*]` **Campo de Minas da DMZ Abrolhos** (Oliva / Neutro)
* **Áudio Procedural Chiptune/Retro:** Efeitos sonoros gerados dinamicamente via código (`AudioStreamGenerator`) para cliques mecânicos de teclado, digitação teletipo, sirenes de Alerta Vermelho, desvio com Chaff e disparos de laser.

---

## ⚙️ Mecânicas de Jogo

### 1. Loop Semi-Real-Time com Pausa Tática (Estilo *FTL*)
O tempo na ponte corre continuamente em pulsos táticos automáticos (a cada 1.4s), enquanto torpedos cruzam o radar. Pressione **ESPAÇO** ou o botão **`[ || PAUSA TÁTICA ]`** para congelar o tempo, pensar com calma e dar ordens.

### 2. O Relógio-Bomba & O Dilema do Teletransporte
* O **Baependi** está em colapso crítico de antimatéria com um **timer visível de contagem regressiva**.
* Há **380 civis a bordo**.
* **O Dilema:** Para teletransportar os civis para a sua nave, **você precisa desligar completamente os seus escudos defletores**. Cada pulso resgata 45 civis, mas qualquer disparo fascista que atingir a sua nave durante a operação vai **direto no casco nu**!

### 3. Escudos Direcionais em 4 Quadrantes & Manobra de Giro
* A nave possui 4 quadrantes independentes de escudo: **Proa (FWD)**, **Popa (AFT)**, **Bombordo (PORT)** e **Boreste (STBD)**.
* Os torpedos causam dano no setor específico de onde vieram. Se um lado colapsar, use a ação de leme **`[ GIRAR NAVE (+90°) ]`** para manobrar e expor um quadrante intacto à linha de tiro inimiga!

### 4. Batalha Eletrônica e Contramedidas
* **`[ LASERS / INTERCEPTAR ]`:** Tenta abater torpedos hostis no ar antes da colisão.
* **`[ ISCAS / CHAFF ]`:** Ejeta cartuchos de contramedidas que desviam torpedos em curso de colisão.
* **`[ REPARAR CASCO ]`:** O Engenheiro Barbosa lidera equipes de contenção de avarias.

---

## 🎯 Plataformas Suportadas

O projeto foi projetado com interface adaptável para:
- 🖥️ **Windows**
- 🐧 **Linux**
- 📱 **Android** (botões táteis com suporte nativo a telas touch)

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
4. Pressione **F5** para iniciar a simulação!

---

## 📄 Licença

Distribuído sob a licença MIT. Consulte `LICENSE` para mais detalhes.
