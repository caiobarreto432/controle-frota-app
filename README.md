# Controle de Frota PMBA

Aplicativo em Flutter para controle de viaturas, checklists de saída e devolução, registros de turno e acompanhamento de manutenção preventiva. Consome uma API REST em Node.js/Express conectada a um banco PostgreSQL.

## O que o app faz

- Autenticação por matrícula e senha com token JWT armazenado em Android Keystore / iOS Keychain (`flutter_secure_storage`).
- Controle de acesso por perfil (`ADMIN` e `POLICIAL`).
- Cadastro e gerenciamento de viaturas (`CARRO` e `MOTO`) com alerta de revisão por quilometragem (`km_atual` vs `km_proxima_manutencao`).
- Checklist duplo obrigatório na retirada (`SAIDA`) e devolução (`RETORNO`) da viatura, com observação por item e anexo de até 5 fotos quando houver problema.
- Registro consolidado do turno (hodômetro inicial/final, abastecimento em litros e R$, ocorrências e observações).
- Histórico com filtro por período ("Meus Registros" e Histórico Geral) e geração offline de planilhas `.xlsx` para compartilhamento.

## Tecnologias

- Flutter (Dart `^3.13.2`, Material 3)
- `http`, `flutter_secure_storage`, `image_picker`
- `excel`, `path_provider`, `share_plus`, `url_launcher`
- `flex_color_scheme`, `google_fonts`
- Backend: Node.js / Express + PostgreSQL 15+

## Estrutura

```text
.
├── docs/
│   └── DATABASE.md        # diagrama ER, dicionário de dados, índices e regras do banco
├── scripts/
│   ├── 01_ddl.sql         # criação das 6 tabelas, constraints e 8 índices B-Tree
│   ├── 02_dml.sql         # dados de exemplo (viaturas, policiais, checklists e turnos)
│   └── 03_dql.sql         # 10 consultas operacionais e analíticas
└── lib/
    ├── config.dart        # URL da API e endpoints
    ├── main.dart
    ├── login.dart
    ├── formulario_viatura.dart
    ├── viaturas.dart
    ├── historico.dart
    ├── gerenciar_policiais.dart
    ├── models/            # viatura, checklist, registro e policial
    ├── services/          # session_manager e excel_exporter
    └── widgets/           # fundo_pmba e seletor_fotos
```

## Banco de dados

A modelagem completa, regras de integridade e detalhes das consultas estão em [docs/DATABASE.md](docs/DATABASE.md).

Para subir a estrutura e testar as consultas localmente no PostgreSQL:

```bash
psql -U postgres -d controle_frota -f scripts/01_ddl.sql
psql -U postgres -d controle_frota -f scripts/02_dml.sql
psql -U postgres -d controle_frota -f scripts/03_dql.sql
```

## Rodando o app

A URL base da API e os endpoints ficam configurados em `lib/config.dart`.

```bash
flutter pub get
flutter run
```
