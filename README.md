# Cactus Fight

Plataforma para gestão de academias de judô, jiu-jitsu e outras modalidades. Cada academia administra seus alunos e suas cobranças e oferece um portal com sua própria identidade visual.

## Experiência por perfil

| Perfil | Onde entra | O que faz |
|---|---|---|
| Dono ou administrador | Painel web responsivo | Configura a academia, convida professores, define permissões, cadastra ou importa alunos, conecta o Asaas e acompanha as mensalidades. |
| Professor | Mesmo painel, com permissões próprias | Gerencia turmas, horários, alunos e graduações conforme as permissões concedidas pela academia. |
| Aluno ou responsável | Portal da academia pelo celular | Ativa a conta, entra com CPF e senha, consulta agenda, graduação e mensalidades e abre a fatura para pagar. |
| Administrador da plataforma | Área administrativa da Cactus | Gerencia cadastro de academias, plano, período de avaliação e status da assinatura. Acesso de suporte deve ser restrito e auditado. |

A primeira versão terá um painel web para a equipe e um portal instalável pelo navegador para alunos. Ambos usam a mesma API. O portal pode ter nome, logotipo, ícone, cor principal e endereço próprios por academia. Modalidades, planos, horários, carência e dias de vencimento são configurações da academia. O endereço define a academia e a API confirma se a sessão pertence a ela.

A etapa seguinte pode oferecer um único aplicativo Flutter para alunos, com seleção da academia e personalização carregada pela API. O ícone da loja e o nome da listagem pertencem ao aplicativo publicado. A marca de cada academia aparece dentro dele. Um app exclusivo por cliente fica condicionado a escopo comercial e revisão das regras de publicação das lojas.

## Produto mínimo para o piloto

1. Criar uma academia e personalizar a página de entrada com nome, cor e logotipo.
2. Cadastrar, editar, ativar e inativar alunos. Vincular responsáveis, definir matrícula, modalidade, turma, faixa, mensalidade e vencimento.
3. Gerenciar professores, grade semanal e faixas por modalidade. Usar modelos iniciais de judô, jiu-jitsu e muay thai, com opções de edição pela academia.
4. Mostrar no painel o total de alunos ativos e cobranças pagas, pendentes e vencidas. Permitir exportação de cadastros e financeiro por perfil autorizado.
5. Conectar a conta Asaas da academia, testar a conexão e importar clientes ou vincular cadastros já existentes.
6. Convidar o aluno ou responsável por link de uso único. Após definir a senha, permitir entrada por CPF no portal da academia. Exibir agenda, graduação, mensalidades e histórico.
7. Permitir abrir a fatura do Asaas para pagamento e atualizar o status automaticamente. Confirmar pagamentos, cancelamentos e estornos com base no Asaas.
8. Liberar o piloto com duas academias distintas para verificar isolamento, personalização e recuperação de acesso.

Presença, avisos automáticos, aplicativo Flutter nas lojas, integração física com catracas e provedores como Wellhub e TotalPass entram no backlog. O painel deve identificar o status do aluno, da matrícula, da cobrança e da assinatura da academia de forma independente.

## Fluxo Asaas

### Conexão

O dono ou um administrador autorizado fornece uma chave da conta Asaas da academia no painel. A API testa a integração, guarda a chave criptografada e apresenta apenas o status da conexão. Segredos de produção e sandbox são separados. A chave fica disponível exclusivamente ao backend, com possibilidade de rotação e registro de alterações.

### Importação e vínculo

- **Direto pela API**: listar pagamentos, clientes e assinaturas com paginação. Oferecer seleção de clientes com assinatura Asaas ativa e seleção manual para academias que usam cobranças avulsas. Contas Asaas mistas podem conter outros tipos de cliente. O professor revisa a seleção e define o status da matrícula.
- **Por arquivo**: importar a planilha exportada do Asaas, com prévia, mapeamento de colunas e relatório de erros. Importar somente as linhas selecionadas e os dados necessários.
- **Base do dojô piloto**: migrar alunos, turmas, faixas, professores e histórico a partir de uma exportação validada. Aproveitar os IDs Asaas existentes quando disponíveis. A migração reaproveita os cadastros e os vínculos financeiros e exclui credenciais e configurações secretas da base antiga.
- **Conflitos**: dentro da academia, priorizar o ID Asaas já associado e usar CPF normalizado quando houver correspondência inequívoca. Se o CPF pertence a um responsável ligado a vários alunos, pedir revisão e vincular o pagador às matrículas corretas. Uma segunda importação deve atualizar os vínculos confirmados sem criar duplicatas.
- **Portabilidade**: exportar alunos ativos ou todos os alunos, conforme o filtro do painel, e permitir exportação financeira com escopo próprio. Relatórios excluem senhas, tokens e credenciais de integração.

Importar ou vincular um aluno preserva as cobranças existentes. A primeira importação mostra os registros encontrados e deixa a emissão de novas cobranças pendente de configuração explícita.

### Mensalidades

Quando a academia já tem recorrência no Asaas, o Cactus acompanha as cobranças geradas por aquela assinatura. Quando a academia optar por emitir mensalidades pelo Cactus, a API mantém uma cobrança por matrícula e competência, reaproveita IDs externos e concilia operações cujo retorno ficou incerto antes de repetir a emissão. O mesmo pagador pode ter mais de uma matrícula legítima.

O portal oferece o link da cobrança existente para o aluno ou responsável pagar pelos meios habilitados na fatura. O webhook usa um token próprio por integração, distinto da chave da API. Os eventos são persistidos e processados uma vez por integração e identificador de evento. A API concilia periodicamente registros com o Asaas para recuperar notificações perdidas e preservar o estado correto em eventos repetidos ou fora de ordem. A academia recebe os valores na conta dela, sujeitos às condições do Asaas. A assinatura da plataforma é cobrada em um fluxo próprio da Cactus.

## Arquitetura e implantação

| Diretório proposto | Responsabilidade |
|---|---|
| `apps/api` | API Java 21 e Spring Boot, autenticação, regras por academia, Asaas e migrações do banco via Flyway. |
| `apps/web` | Painel responsivo e portal instalável do aluno. |
| `apps/mobile` | Aplicativo Flutter compartilhado na etapa de publicação. |
| `infra` | Docker Compose, roteiro de implantação, backups e verificação de recuperação. |

O PostgreSQL é central e privado. Academias, alunos, responsáveis, matrículas, turmas, usuários, personalizações e cobranças têm escopo por academia. A autorização é aplicada no servidor, inclusive em buscas, exportações e links de faturas. Segredos, credenciais e dados reais de clientes ficam fora do Git. Senhas são armazenadas com hash apropriado. CPF é identificador, com mascaramento, proteção em repouso e acesso limitado. O primeiro acesso e a recuperação usam contato verificado e link de curta duração. Turmas infantis podem usar conta do responsável vinculada a mais de um aluno.

A primeira hospedagem pode usar uma VPS Linux com Docker Compose, proxy reverso HTTPS, rede privada para o banco, backup externo e monitoramento. O piloto depende de verificar CPU, memória, disco e carga atuais e validar restauração do banco. A distribuição do app nas lojas é independente de onde a API roda. Se houver migração para a nuvem, serviços como Cloud Run e Cloud SQL podem hospedar a aplicação e o banco.

## Ordem de entrega

| Etapa | Critério de conclusão |
|---|---|
| 1. Fundação e identidade visual | Cada academia tem nome, marca, endereço e sessão próprios. Testes mostram que duas academias ficam isoladas, inclusive por URL direta e exportação. |
| 2. Gestão do dojô | Administrador e professor operam alunos, matrículas, faixas, turmas e grade semanal com as permissões previstas. A base piloto é importada e conferida. |
| 3. Financeiro e portal | Aluno ou responsável ativa a conta por convite, entra com CPF, vê a fatura e faz um pagamento de teste. Reimportar e reenviar o webhook preservam os registros existentes. |
| 4. Piloto comercial | Piloto com o dojô de referência e uma segunda academia, backups restaurados em teste, documentação de onboarding e suporte e assinatura da plataforma validada. |
| 5. Publicação nas lojas | Após validar o uso do portal, decidir se o Flutter traz ganho de distribuição e publicar o app compartilhado com a experiência por academia. |

## Preço inicial para validar

R$ 30 por mês por unidade é a hipótese comercial do piloto. A cobrança cobre o acesso ao software. As taxas de recebimento das mensalidades são as da conta Asaas de cada academia. Antes de fixar o preço definitivo, medir tempo de implantação, volume de suporte por cliente e custo mensal de infraestrutura. Em uma simulação, 10 academias pagantes representam R$ 300 brutos mensais e 50 representam R$ 1.500 brutos mensais.

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
