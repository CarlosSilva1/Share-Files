# GUIA COMPLETO: Atualização de MAISEA_1.MQ4 para MAISEA_2.MQ4

## 1. Introdução
Neste guia, iremos realizar a atualização do código do arquivo MAISEA_1.MQ4 para MAISEA_2.MQ4. Essa atualização envolve a implementação de novos parâmetros, mudanças no código, e a criação de novas funções para garantir que o código seja otimizado e funcione corretamente.

## 2. Lista Completa de Mudanças Necessárias
- Atualização dos parâmetros utilizados no código.
- Implementação das funções DrawLogoMAIS_HD() e DeleteLogoMAIS_HD().
- Remoção de funções obsoletas como CreateMaisLogo e DeleteMaisLogo.
- Modificação das chamadas de OnInit() e OnDeinit().
- Inclusão de lógica para o bitmap do logo.

## 3. Novos Parâmetros a Serem Adicionados Após a Linha 59
```mql4
// Parâmetros a serem adicionados
input int NovoParametro1 = 1;
input double NovoParametro2 = 0.5;
input string NovoParametro3 = "Param3";
```

## 4. Implementação Completa da Função DrawLogoMAIS_HD()
```mql4
void DrawLogoMAIS_HD() {
    // Lógica para criar o logo
    ResourceCreate();
    string logoName = "Logo_MAIS_HD";
    int logoWidth = 200;
    int logoHeight = 100;
    ObjectCreate(0, logoName, OBJ_BITMAP_LABEL, 0, 0, 0);
    ObjectSetInteger(0, logoName, OBJ_XSIZE, logoWidth);
    ObjectSetInteger(0, logoName, OBJ_YSIZE, logoHeight);
    ObjectSetInteger(0, logoName, OBJ_ALPHA, 255); // Transparência definindo o valor aqui
    // Lógica para adicionar os pixels do logo
    // Cole os 16800 pixels aqui:
    // pixels[0] ... pixels[16799]
}
```

## 5. Implementação Completa da Função DeleteLogoMAIS_HD()
```mql4
void DeleteLogoMAIS_HD() {
    ObjectDelete("Logo_MAIS_HD");
}
```

## 6. Instruções Sobre Quais Funções Antigas Deletar
Deve-se remover as seguintes funções do código:
- `CreateMaisLogo` (linhas 882-900)
- `DeleteMaisLogo` (linhas 901-961)

## 7. Como Atualizar as Chamadas das Funções OnInit() e OnDeinit()
No início do arquivo, localize as funções `OnInit()` e `OnDeinit()`. A alteração pode ser feita conforme abaixo:

### Atualização de OnInit()
```mql4
int OnInit() {
    // Inicialização do logo
    DrawLogoMAIS_HD();
    return INIT_SUCCEEDED;
}
```

### Atualização de OnDeinit()
```mql4
void OnDeinit(const int reason) {
    DeleteLogoMAIS_HD();
}
```

## 8. Passo a Passo para Copiar a Array de Pixels do Logo_MAIS_HD_Final.mq4
1. Abra o arquivo `Logo_MAIS_HD_Final.mq4`.
2. Localize as linhas que contêm a definição da array de pixels (de linhas 14 até o final da definição).
3. Copie todas as definições de `pixels[0]` até `pixels[16799]`.
4. Cole no local indicado na função `DrawLogoMAIS_HD()`.

## 9. Instruções de Compilação
- Abra o MetaEditor.
- Insira o código atualizado.
- Clique em "Compilar" (ou pressione F7).
- Verifique se não há erros de compilação.

## 10. Checklist de Testes
- Verifique se o logo aparece corretamente.
- Teste a funcionalidade das novas entradas e parâmetros.
- Execute operações de negociação para garantir que tudo esteja funcionando.

## 11. Seção de Solução de Problemas
- **Problema:** O logo não aparece.
  - **Solução:** Verifique se você adicionou a função `DrawLogoMAIS_HD()` corretamente.
- **Problema:** Erros de compilação estão ocorrendo.
  - **Solução:** Revise todos os parâmetros e funções adicionadas ou modificadas.