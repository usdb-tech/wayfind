# wayfind
Localizador de cotas para integração em SGIB

# 🗺️ Localizador de Obras Koha/USDB (Classic ASP)
_Integração para visualização espacial de cotas no catálogo Koha_

A funcionalidade Localizador de Obras da USDB (Serviços de Documentação e Bibliotecas da Universidade do Minho) é uma aplicação desenvolvida em Classic ASP (VBScript) que se integra no catálogo Koha. O seu objetivo é oferecer mapeamento espacial e visualização da localização física de publicações com base na sigla da biblioteca e na Classificação Decimal Universal (CDU).

## ✨ Resumo da Iniciativa

Esta iniciativa responde à complexidade espacial e organizacional das bibliotecas da Universidade do Minho,, que se traduz em desafios para os utilizadores na localização autónoma de publicações. O Localizador de Obras atua como uma ponte entre o registo digital (catálogo) e o espaço físico (biblioteca), tornando a informação mais precisa e esclarecedora.

O código foi desenvolvido de forma modular e aberta, estando disponível para adaptação em qualquer versão do Koha ou sistemas compatíveis.

## ⚙️ Arquitetura e Funcionamento Técnico

O Localizador de Obras corre como uma aplicação *standalone* num servidor Windows com IIS (Internet Information Services), separado do servidor Koha.

A funcionalidade é acionada através de um link dinâmico no registo do exemplar no Koha, que abre uma janela embebida (`iframe`) a partir do ficheiro principal da aplicação: **`wayfind.asp`**.

### 💻 Componentes Chave

| Componente | Função | 
| :--- | :--- |
| **Koha (OPAC)** | Aciona o localizador, passando a cota completa via `QueryString`. |
| **Servidor Localizador** | Executa o script ASP, consulta a BD, verifica a planta e devolve o HTML bilingue. | 
| **Base de Dados** | Mapeia siglas e intervalos da CDU para plantas e informações contextuais. | 

### 🚀 Fluxo de Execução

1.  O utilizador clica no link da cota no Koha.
2.  O script **`wayfind.asp`** recebe a cota completa (ex: `BGUM 681.3 - C`).
3.  O script processa o *input*, dividindo-o em **Sigla** e **CDU** (eliminando elementos de ordenação alfabética).
4.  É executado um **Processo Iterativo de Busca pela Notação Mais Longa**: a pesquisa inicia na classificação mais geral (ex: primeiro dígito) e aumenta progressivamente o nível de especificidade (ex: `6` → `68` → `681`, etc.) até encontrar o intervalo de estantes mais específico na Base de Dados.
5.  O sistema verifica a existência do ficheiro de imagem da planta no servidor (`/plantas/`).
6.  O resultado é devolvido, apresentando a planta simplificada com a localização destacada ou, em alternativa, informação bilingue (PT/EN) sobre localização, acesso e modo de consulta.

### 🛡️ Segurança e Manutenção

A separação do localizador do Koha garante segurança e flexibilidade:

* O código ASP liga-se diretamente à base de dados interna com credenciais próprias, o que permite aplicar regras de firewall e CORS (`Access-Control-Allow-Origin`) específicas.
* A manutenção e evolução do localizador (incluindo uma futura migração para outra tecnologia como PHP ou .NET Core) podem ser realizadas sem interferir no servidor Koha.

## 📖 Como Usar (Configuração)

Exemplo de estrutura de diretórios:

```plaintext
/wayfind/
├── wayfind.asp
├── plantas/
└── README.md
```

Para implementar esta funcionalidade:

1.  **Configurar o Servidor:** Necessitará de um servidor Windows ou Linux configurado para executar Classic ASP e de um servidor de base de dados (pode ser o mesmo)
2.  **Copiar Ficheiros:** Colocar o **`wayfind.asp`** e a pasta `plantas/` no diretório web.
3.  **Configurar Credenciais:** **IMPORTANTE**: No ficheiro **`wayfind.asp`** no servidor de produção, substitua os *placeholders* da string DSN pelas credenciais reais:

```vbscript
' Credenciais de Teste para o GitHub, DEVEM ser substituídas no servidor!
DSN = "Driver={SQL Server};Server=SEU_SERVIDOR_AQUI;Database=SUA_BD_AQUI;UID=SEU_UTILIZADOR_AQUI;PWD=SUA_PASSWORD_AQUI"
```

4.  **Integrar no Koha:** No OPAC (página do registo completo), configurar um link na área dos exemplares que aponte para a aplicação, passando a cota via `QueryString`. Pode ser usado link para outra página ou desenvovido um script que crie uma iframe onde é mostrado o conteúdo:

```html
https://servidor-asp/wayfind.asp?cota=cota-completa
```

## 📦 Estrutura da Base de Dados

A aplicação utiliza uma base de dados composta por três tabelas principais:

### 🏛️ Tabela `sub-bibs`
Contém a informação de identificação e contacto das sub-bibliotecas.

| Coluna | Tipo | Descrição |
| :--- | :--- | :--- |
| `sigla` | varchar(50) | Sigla única da sub-biblioteca (chave primária) |
| `nome` | varchar(100) | Nome da biblioteca |
| `nome_en` | varchar(100) | Nome da biblioteca em inglês |
| `url` | varchar(100) | URL para a página com mais informações sobre a biblioteca |
| `info` | varchar(420) | Informações adicionais (PT) |
| `info_en` | varchar(420) | Informação adicionoais (EN) |
| `local` | varchar(100) | Localização física (PT) |
| `local_en` | varchar(100) | Localização física (EN) |

---

### 📚 Tabela `cotas`
Mapeia os intervalos de CDU às plantas e descrições de localização.

| Coluna | Tipo | Descrição |
| :--- | :--- | :--- |
| `sigla` | nvarchar(50) | Sigla da biblioteca (referência à `sub-bibs`) |
| `cota` | nvarchar(50) | Intervalo ou notação CDU |
| `planta` | nvarchar(50) | Nome do ficheiro da planta (imagem) |
| `info` | nvarchar(200) | Informação contextual (PT) |
| `info_en` | nvarchar(200) | Informação contextual (EN) |
| `ID` | int | Identificador único (chave primária) |

---

### ⚠️ Tabela `erros`
Regista erros e ocorrências de processamento.

| Coluna | Tipo | Descrição |
| :--- | :--- | :--- |
| `data` | char(20) | Data/hora do erro |
| `cota` | char(20) | Cota processada |
| `cb` | char(20) | Sigla da biblioteca |
| `erro` | char(100) | Descrição do erro |
| `id` | int | Identificador único (chave primária) |

---

> ⚙️ **Nota:** as plantas (imagens) referenciadas em `planta` devem estar na pasta `/plantas/` do servidor IIS.  
> O script `wayfind.asp` usa consultas SQL diretas a estas tabelas para determinar a localização mais específica com base na CDU.

---

## 👥 Contribuições

O desenvolvimento técnico encontra-se disponível para a comunidade internacional em acesso aberto no GitHub, em conformidade com a filosofia do software livre.  
Agradecemos contributos, sugestões ou melhorias através de *issues* ou *pull requests*.  

## 👥 Autoria

Projeto desenvolvido pelos [Serviços de Documentação e Bibliotecas da Universidade do Minho (USDB)](https://www.usdb.uminho.pt).

Ideia e conceção: **[Daniela Castro] daniela.castro@usdb.uminho.pt**  
Desenvolvimento: **[Nuno Fernandes] nuno.fernandes@usdb.uminho.pt**  
