# Cactus Fight

Plataforma para gestão de academias de judô, jiu-jitsu e outras modalidades. Cada academia administra seus alunos e suas cobranças e oferece um portal com sua própria identidade visual.


## Cadastro inicial disponível nesta versão

O fluxo Flutter em `apps/mobile` cria a academia pela API, salva plano, vencimento, meio de pagamento e identidade visual, e confirma o e-mail do responsável por código. Os valores são calculados no servidor a R$ 30 no mensal e R$ 324 no anual. O backend conserva a solicitação pendente quando o envio por e-mail falha e permite reenviar o código. A primeira fatura fica em `PENDING_PAYMENT` até a etapa de integração com o Asaas.

A API em `apps/api` parte da fundação do repositório `dojo-tigre-fight-web-access`, revisão `e592c69`. As migrações preparam um banco dedicado para o aplicativo.

```sh
cp .env.example .env
# Preencha os dados SMTP e ONBOARDING_FROM antes de iniciar.
docker compose up -d --build

cd apps/mobile
flutter pub get
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8080
```

O exemplo Flutter usa um emulador Android e API na máquina local. Em aparelho físico use o endereço HTTPS de homologação. Confirme o estado da API em `/actuator/health`. O primeiro vencimento aceita datas dentro dos próximos 30 dias no horário de Fortaleza. São aceitos logos PNG ou JPEG de até 2 MB. Configure as credenciais de produção, o SMTP e o proxy HTTPS na VPS antes do piloto.

## Experiência por perfil

Um único aplicativo Flutter atende todas as academias e apresenta as telas conforme as permissões do usuário. O backend e o banco central rodam na VPS.

| Perfil | Como começa | O que faz no app |
|---|---|---|
| Dono da academia | Toca em **Cadastrar minha academia**, confirma o contato e cria a conta | Cadastra a academia, define nome, logo e cor, convida professores, configura modalidades e planos, cadastra ou importa alunos, conecta o Asaas e acompanha a assinatura da plataforma. |
| Professor | Aceita o convite da academia e define a senha | Gerencia turmas, horários, graduações e alunos de acordo com as permissões. Pode convidar alunos quando autorizado. |
| Aluno ou responsável | Abre o convite no app ou digita o código recebido | Confirma o cadastro e define a senha. Nos acessos seguintes, entra com CPF e senha no contexto da academia. Consulta agenda, graduação e mensalidades. |
| Administrador da plataforma | Acessa a área restrita da Cactus | Gerencia academias, plano, período de avaliação e status da assinatura. O acesso de suporte é restrito e auditado. |

O cadastro da academia, a ativação de contas e a gestão do dojô acontecem no aplicativo desde o piloto. O dono pode compartilhar o convite pelo WhatsApp ou copiar o código para enviar por outro canal. O link abre o app quando instalado. Quem ainda precisa instalar recebe instruções e pode usar o código na tela **Tenho um convite** depois da instalação.

O convite tem validade, é de uso único e está vinculado à academia, ao perfil e ao cadastro que o originou. A equipe pode reenviar ou revogar convites pendentes. Um aluno adulto e um responsável podem acessar a conta com o próprio CPF. O responsável pode ter mais de um aluno vinculado.

Nome, logotipo e cor são exibidos no convite e nas telas da academia. A listagem e o ícone principal na loja identificam o Cactus Fight. O servidor valida a academia da sessão em cada operação.


## Produto mínimo para o piloto

1. Permitir que o dono cadastre a academia, confirme seu contato e personalize nome, logo e cor pelo app.
2. Cadastrar, editar, ativar e inativar alunos. Vincular responsáveis e definir matrícula, modalidade, turma, faixa, mensalidade e vencimento.
3. Gerenciar professores, grade semanal e faixas por modalidade. Usar modelos iniciais de judô, jiu-jitsu e muay thai, com opções de edição pela academia.
4. Mostrar no app o total de alunos ativos e cobranças pagas, pendentes e vencidas. Permitir exportação de cadastros e do financeiro por perfil autorizado.
5. Conectar a conta Asaas da academia no app, testar a conexão e importar clientes ou vincular cadastros já existentes. Permitir selecionar uma planilha pelo seletor de arquivos do celular.
6. Convidar o aluno ou responsável no cadastro do aluno. Após aceitar o convite e definir a senha, o usuário entra com CPF e vê agenda, graduação, mensalidades e histórico.
7. Oferecer pagamento das mensalidades pelo celular. Exibir Pix copia e cola e, quando disponível, a linha digitável do boleto. Confirmar pagamentos, cancelamentos e estornos com base no Asaas.
8. Liberar o piloto para duas academias distintas e validar o fluxo a partir de um celular sem sessão anterior.

Presença, avisos automáticos, integração física com catracas e provedores como Wellhub e TotalPass entram no backlog. O app distingue os estados do aluno, da matrícula, da cobrança e da assinatura da academia.

## Fluxo Asaas

### Conexão

O dono ou um administrador autorizado fornece uma chave da conta Asaas da academia no aplicativo. A API testa a integração, guarda a chave criptografada e apresenta apenas o status da conexão. Segredos de produção e sandbox são separados. A chave fica disponível exclusivamente ao backend, com possibilidade de rotação e registro de alterações.

### Importação e vínculo

- **Direto pela API**: listar pagamentos, clientes e assinaturas com paginação. Oferecer seleção de clientes com assinatura Asaas ativa e seleção manual para academias que usam cobranças avulsas. Contas Asaas mistas podem conter outros tipos de cliente. O professor revisa a seleção e define o status da matrícula.
- **Por arquivo**: importar a planilha exportada do Asaas, com prévia, mapeamento de colunas e relatório de erros. Importar somente as linhas selecionadas e os dados necessários.
- **Base do dojô piloto**: migrar alunos, turmas, faixas, professores e histórico a partir de uma exportação validada. Aproveitar os IDs Asaas existentes quando disponíveis. A migração reaproveita os cadastros e os vínculos financeiros e exclui credenciais e configurações secretas da base antiga.
- **Conflitos**: dentro da academia, priorizar o ID Asaas já associado e usar CPF normalizado quando houver correspondência inequívoca. Se o CPF pertence a um responsável ligado a vários alunos, pedir revisão e vincular o pagador às matrículas corretas. Uma segunda importação deve atualizar os vínculos confirmados sem criar duplicatas.
- **Portabilidade**: exportar alunos ativos ou todos os alunos, conforme o filtro do aplicativo, e permitir exportação financeira com escopo próprio. Relatórios excluem senhas, tokens e credenciais de integração.

Importar ou vincular um aluno preserva as cobranças existentes. A primeira importação mostra os registros encontrados e deixa a emissão de novas cobranças pendente de configuração explícita.

### Mensalidades

Quando a academia já tem recorrência no Asaas, o Cactus acompanha as cobranças geradas por aquela assinatura. Quando a academia optar por emitir mensalidades pelo Cactus, a API mantém uma cobrança por matrícula e competência, reaproveita IDs externos e concilia operações cujo retorno ficou incerto antes de repetir a emissão. O mesmo pagador pode ter mais de uma matrícula legítima.

O aplicativo exibe os dados de pagamento da cobrança existente, conforme os meios disponíveis. O aluno pode copiar o código Pix ou a linha digitável e concluir no aplicativo bancário. Cartão pela fatura hospedada do Asaas fica como evolução a homologar. O webhook usa um token próprio por integração, distinto da chave da API. Os eventos são persistidos e processados uma vez por integração e identificador de evento. A API concilia periodicamente registros com o Asaas para recuperar notificações perdidas e preservar o estado correto em eventos repetidos ou fora de ordem. A academia recebe os valores na conta dela, sujeitos às condições do Asaas. A assinatura da plataforma é cobrada em um fluxo próprio da Cactus.


## Arquitetura e implantação

| Diretório proposto | Responsabilidade |
|---|---|
| `apps/api` | API Java 21 e Spring Boot, autenticação, regras por academia, Asaas e migrações do banco via Flyway. |
| `apps/mobile` | App Flutter com cadastro da academia, área da equipe, área do aluno ou responsável e configuração do Asaas. |
| `infra` | Docker Compose, roteiro de implantação, backups e verificação de recuperação. |

O PostgreSQL é central e privado. Academias, alunos, responsáveis, matrículas, turmas, usuários, personalizações e cobranças têm escopo por academia. A autorização é aplicada no servidor, inclusive em buscas, exportações e acesso às faturas. Segredos, credenciais e dados reais de clientes ficam fora do Git. Senhas são armazenadas com hash apropriado. CPF é identificador, com mascaramento, proteção em repouso e acesso limitado. O primeiro acesso e a recuperação usam convite ou código de curta duração e contato verificado.

A implantação inicial está prevista na VPS `cactus-main`, com Docker Compose, Caddy para HTTPS, rede privada para o PostgreSQL, backup externo e monitoramento. Antes do piloto, verificar CPU, memória, disco, carga dos serviços existentes e restauração do banco. O app se comunica por HTTPS com a API. A Google Play distribui o app Android e o TestFlight pode ser usado em um piloto iOS, se incluído no escopo.


## Ordem de entrega

| Etapa | Critério de conclusão |
|---|---|
| 1. Fundação e cadastro | O dono instala o app, confirma o contato, cria sua academia e personaliza a marca. Testes verificam que duas academias ficam isoladas. |
| 2. Gestão e convite | A equipe opera alunos, matrículas, faixas, turmas e grade semanal. O professor autorizado cadastra e convida um aluno. O aluno ou responsável aceita no aplicativo e entra com CPF e senha. |
| 3. Asaas e pagamentos | A academia conecta o Asaas e importa os alunos pelo app. O responsável ou aluno consulta e paga uma mensalidade de teste. Reimportação e reentrega do webhook preservam os registros existentes. |
| 4. Piloto comercial | O dojô de referência e uma segunda academia completam o fluxo pelo celular. O backup é restaurado em teste e a contratação do plano é validada para o canal de distribuição escolhido. |

## Preço inicial para validar

R$ 30 por mês por unidade é a hipótese comercial do piloto. A cobrança cobre o acesso ao software. O cadastro inicial pode começar com período de avaliação configurável. A contratação paga do plano deve seguir a política aplicável ao canal de distribuição. O app mostra o estado da assinatura da própria academia. As taxas de recebimento das mensalidades são as da conta Asaas de cada academia. Antes de fixar o preço definitivo, medir tempo de implantação, volume de suporte por cliente e custo mensal de infraestrutura. Em uma simulação, 10 academias pagantes representam R$ 300 brutos mensais e 50 representam R$ 1.500 brutos mensais.

## Referências externas

- [Asaas — listar clientes](https://docs.asaas.com/reference/listar-clientes)
- [Asaas — listar assinaturas](https://docs.asaas.com/reference/listar-assinaturas)
- [Asaas — exportar clientes](https://central.ajuda.asaas.com/hc/pt-br/articles/45609141216283-Como-exportar-meus-clientes)
- [Asaas — cobranças e fatura](https://docs.asaas.com/docs/guia-de-cobrancas)
- [Asaas — idempotência em webhooks](https://docs.asaas.com/docs/como-implementar-idempotencia-em-webhooks)
- [Google Play — política de pagamentos](https://support.google.com/googleplay/android-developer/answer/10281818?hl=pt-BR)
- [Google Play — conteúdo repetitivo](https://support.google.com/googleplay/android-developer/answer/9899034)
- [Apple — revisão de apps](https://developer.apple.com/app-store/review/guidelines/)
- [ANPD — dados pessoais de crianças e adolescentes](https://www.gov.br/anpd/pt-br/assuntos/noticias/anpd-divulga-enunciado-sobre-o-tratamento-de-dados-pessoais-de-criancas-e-adolescentes)
