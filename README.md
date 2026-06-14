# Spooner Versao TWS

Esta e uma versao modificada do Spooner para RedM, distribuida como free resource pela The Wanted Sole Studio.

A base original do projeto pertence ao `kibook/spooner`. A The Wanted Sole Studio fez ajustes, melhorias internas e adicionou funcoes para facilitar o uso dentro do servidor.

## Informacoes

| Campo | Valor |
| --- | --- |
| Nome | Spooner Versao TWS |
| Categoria | Free Resource |
| Base original | kibook/spooner |
| Modificado por | The Wanted Sole Studio |
| Plataforma | RedM |
| Status | Gratuito |

## O que foi alterado

- Script ajustado para uso em servidores RedM.
- Interface ajustada para o padrao visual TWS.
- Nova funcao para localizar peds/metapeds carregados no servidor.
- Suporte a peds em formatos comuns de resource, como `stream`, `data_files`, `data` e `metapeds`.
- Suporte a pastas customizadas via `Config.PedResourcePathHints`.
- Suporte a lista manual de peds via `Config.ServerPeds`.
- Ajustes internos para facilitar uso, busca e organizacao.
- Resource preparado para distribuicao como free resource.

## Peds do servidor

Esta versao tenta encontrar automaticamente os peds/metapeds que estao iniciados no servidor. O scanner procura modelos em resources ativos, arquivos `.ymt`, manifests e `data_files/metapeds.ymt`.

Se algum pack estiver em uma pasta com nome diferente, adicione o nome em `shared/config.lua`:

```lua
Config.PedResourcePathHints = {
    '[peds]',
    'custompeds',
    'personagens',
    'characters',
    'minha_pasta_de_peds',
}
```

Se algum modelo ainda nao aparecer, force manualmente:

```lua
Config.ServerPeds = {
    'cs_nome_do_ped',
}
```

Depois de adicionar ou iniciar novos peds, use no console:

```text
spooner_rescan_peds
```

## Instalacao

1. Baixe o resource.
2. Coloque a pasta `spooni_spooner` dentro da sua pasta `resources`.
3. Garanta que a dependencia `uiprompt` esteja instalada.
4. Adicione no seu `server.cfg`:

```cfg
ensure spooni_spooner
```

5. Adicione tambem as permissoes:

```cfg
exec @spooni_spooner/permissions.cfg
```

Ou configure manualmente:

```cfg
add_ace group.admin spooner.view allow
add_ace group.admin spooner.spawn allow
add_ace group.admin spooner.modify.own allow
add_ace group.admin spooner.delete.own allow
add_ace group.admin spooner.properties allow

add_ace group.admin spooner.noEntityLimit allow
add_ace group.admin spooner.modify.other allow
add_ace group.admin spooner.delete.other allow
```

6. Reinicie o servidor.

## Comandos

| Comando | Funcao |
| --- | --- |
| `/spooner` | Abre ou fecha o spooner |
| `/spooner_db` | Abre o menu de database |
| `/spooner_savedb` | Abre o menu de salvar/carregar database |
| `spooner_refresh_perms` | Recarrega permissoes dos players |
| `spooner_rescan_peds` | Reescaneia peds/metapeds do servidor |

## Controles principais

| Controle | Funcao |
| --- | --- |
| W/A/S/D | Mover |
| Space/Shift | Subir/descer |
| E | Spawnar |
| Clique esquerdo | Selecionar/anexar/desanexar entidade |
| Clique direito | Deletar entidade selecionada |
| C/V | Rotacionar |
| B | Trocar eixo de rotacao |
| Q/Z/Setas | Ajustar posicao |
| F | Abrir menu de spawn |
| X | Abrir database |
| Tab | Abrir propriedades |
| J | Abrir salvar/carregar database |
| Delete | Sair do spooner |

## Menus

### Spawn

O menu de spawn possui listas pesquisaveis para peds, veiculos, objetos, propsets, pickups e outros tipos suportados.

Se um modelo nao estiver na lista, ainda e possivel digitar o nome completo no campo de busca e usar `Criar por Nome`, desde que o player tenha permissao para spawn por nome.

### Database

O menu de database armazena as entidades criadas. Entidades spawnadas entram automaticamente no database atual.

- Clique esquerdo abre a entidade no menu de propriedades.
- Clique direito deleta a entidade.
- `Delete All` remove todas as entidades do database.

### Propriedades

O menu de propriedades permite editar posicao, rotacao, congelamento, visibilidade, colisao, vida, invencibilidade, anexos e opcoes especificas de ped/veiculo.

### Salvar e carregar

O menu de salvar/carregar permite guardar databases por nome e carregar depois.

- Para salvar, digite um nome e clique em `Save`.
- Para carregar, clique no nome salvo.
- Para deletar, clique com o botao direito no nome salvo.
- Para importar/exportar, use `Import/Export`.

## Importacao e exportacao

Formatos suportados:

| Formato | Exporta | Importa |
| --- | --- | --- |
| YMAP | Sim | Sim |
| Map Editor XML | Sim | Sim |
| Spooner DB JSON | Sim | Sim |
| Spooner Backup | Sim | Sim |
| Prop Loader | Sim | Sim |
| propplacer JSON | Sim | Nao |

## Creditos

Este resource e baseado no projeto original:

- `kibook/spooner`

Todos os creditos da base original pertencem ao autor original.

A The Wanted Sole Studio realizou apenas modificacoes, ajustes, organizacao e adicao de funcoes nesta versao.

## Suporte

Resource gratuito da The Wanted Sole Studio.
