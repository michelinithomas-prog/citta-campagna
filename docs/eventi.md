# Gli incontri

> Capitano fra una battaglia e l'altra, non al primo round e non sempre. Ogni incontro esce una volta sola per partita.
>
> Generato da `tools/genera_manuale.gd` — non modificarlo a mano:
> alla prossima rigenerazione le modifiche spariscono. Cambia i JSON in `game/data/`.

Probabilità che ne capiti uno: **50%** per round, dal round **2** in poi.


---

## La fiera del paese

*Dal round 2 in poi.*

> Il piazzale è pieno di banchi. Hai un carro mezzo vuoto e tutto il pomeriggio davanti.

### Vendi quello che hai

*Promette: +12 oro, una carta in meno*

- +12 oro
- toglie 1 carta dal mazzo, a caso

### Compra quello che puoi

*Promette: −12 oro, una carta in più*

- -12 oro
- una carta in più nel mazzo


---

## L'osteria sulla via

*Dal round 2 in poi.*

> Dentro si mangia, si beve e si parla troppo. L'oste ti guarda come si guarda un cliente.

### Mangia e riposa

*Promette: +8 di vita massima*

- +8 di vita massima

### Sta' a sentire i discorsi

*Promette: Racconti di Gaiofana*

- in tasca la reliquia **Racconti di Gaiofana**

### Paga da bere a tutti

*Promette: −10 oro, ma qualcuno si ricorda di te*

- -10 oro
- una carta in più nel mazzo
- una carta in più nel mazzo


---

## Il vecchio sull'aia

*Dal round 3 in poi.*

> Sta seduto da ore. Dice che una volta la terra rendeva il doppio, e che lui sa il perché.

### Ascoltalo fino in fondo

*Promette: Il Valore della Vigna*

- in tasca la reliquia **Il Valore della Vigna**

### Dagli una mano nei campi

*Promette: +15 oro, e una carta di campagna*

- +15 oro
- una carta in più nel mazzo (di Briscola di valore 4-8)


---

## La bottega del fabbro

*Dal round 3 in poi.*

> Batte il ferro senza alzare la testa. «Lasciami una carta, te la restituisco meglio di come me l'hai data.»

### Fatti affilare una carta

*Promette: un innesto Affilato*

- mette il sigillo **Affilato** su una carta a caso

### Chiedigli qualcosa di più fino

*Promette: −12 oro, un innesto Svelto*

- -12 oro
- mette il sigillo **Svelto** su una carta a caso

### Vendigli il ferro vecchio

*Promette: +10 oro, una carta in meno*

- +10 oro
- toglie 1 carta dal mazzo, a caso


---

## Il temporale

*Dal round 3 in poi.*

> Il cielo si chiude in dieci minuti. Il carro è scoperto e il paese è ancora lontano.

### Cerca riparo e aspetta

*Promette: sicuro: −6 oro*

- -6 oro

### Tira dritto sotto l'acqua

*Promette: due su tre finisce bene*

- **a sorte (33%)**: +20 oro
- **a sorte (33%)**: toglie 1 carta dal mazzo, a caso
- **a sorte (34%)**: arriverai alla prossima battaglia con un decimo di vita in meno


---

## Il banco dei pegni

*Dal round 4 in poi.*

> Dietro il vetro c'è un uomo che compra tutto e non chiede mai niente.

### Impegna due carte

*Promette: +22 oro, due carte in meno*

- toglie 2 carte dal mazzo, a caso
- +22 oro

### Compra quello che tiene sotto il banco

*Promette: −18 oro, una carta grossa*

- -18 oro
- una carta in più nel mazzo (di valore 8-13)

### Tira via dritto

*Promette: niente*

- Non succede niente.


---

## Il giocatore

*Dal round 4 in poi.*

> Mischia il mazzo con una mano sola e ti sorride. «Una partita sola. Poi ti lascio in pace.»

### Accetta la sfida

*Promette: metà e metà: +1 vita, oppure −20 oro*

- **50% delle volte**: +1 vita
- **il restante 50%**: -20 oro

### Guarda come gioca

*Promette: impari il mestiere: una figura nel mazzo*

- una carta in più nel mazzo (di Poker di valore 11-13)


---

## La sagra di mezz'agosto

*Dal round 5 in poi.*

> Tavolate lunghe cento metri, fisarmonica, e gente che balla fino a domani.

### Mangia come si deve

*Promette: +12 di vita massima*

- +12 di vita massima

### Balla fino all'alba

*Promette: Una Notte da Ricordare*

- in tasca la reliquia **Una Notte da Ricordare**

### Gioca alla tombola

*Promette: un colpo di fortuna, o una beffa*

- **a sorte (50%)**: +25 oro
- **a sorte (25%)**: mette il sigillo **Eco** su una carta a caso
- **a sorte (25%)**: toglie 1 carta dal mazzo, a caso


---

## Una scelta difficile

*Dal round 2 in poi.*

> La tua compagna arriva sbuffando: un altro sabato pomeriggio buttato a giocare a carte invece di andare al centro commerciale con lei. La situazione è tesa. Devi scegliere.

### Scegli lei

*Promette: la partita finisce qui*

- **la partita finisce qui**

### Scegli l'autobriscola

*Promette: cinque Due di Picche, e valgono il doppio*

- effetto `repeat`
- per tutta la partita: i Due di Picche valgono il doppio


---

## La colletta

*Dal round 2 in poi.*

> Gli anziani dei bar che stai cercando di salvare hanno fatto una colletta. Non è molto, ma è quello che avevano.

### Accetta, e ringrazia

*Promette: una reliquia a caso*

- una reliquia a caso, fra quelle che non hai


---

## L'aziana

*Dal round 2 in poi.*

> Una signora coperta da capo a piedi, di sicuro non della zona, ti viene addosso e tira dritto. Per terra le è caduta una carta. È un Gaiofanamon che non hai mai visto, e il nome ti lascia perplesso: «L'antigh».

### Raccoglila e aggiungila al mazzo

*Promette: L'antigh*

- aggiunge al mazzo: **L'antigh**

### Restituiscila alla signora

*Promette: una reliquia a caso*

- una reliquia a caso, fra quelle che non hai

### Sembra da collezione: vendila

*Promette: +35 oro*

- +35 oro


---

## Un problema shockante

*Dal round 2 in poi.*

> Passi in un vicolo e senti qualcosa venire da un bidone lì accanto. Ti si rizzano i peli sulle braccia e l'aria sa di temporale.

### Procedi a passo svelto

*Promette: niente*

- Non succede niente.

### Rovista nel bidone

*Promette: prendi Sorc, ma la paghi*

- aggiunge al mazzo: **Sorc**
- la prossima battaglia comincerà con le carte intorpidite


---

## Appare un professore selvatico

*Dal round 2 in poi.*

> Un signore vestito come se fosse in laboratorio ti chiede se sai cosa sono i Gaiofanamon. Fai cenno di sì, e lui subito ti domanda se ne vuoi uno che ti aiuti nell'impresa.

### Prendi l'Acqua

*Promette: un Cucciolo d'Acqua*

- aggiunge al mazzo: **Sgorga**

### Prendi il Fuoco

*Promette: un Cucciolo di Fuoco*

- aggiunge al mazzo: **Scintela**

### Prendi l'Erba

*Promette: un Cucciolo d'Erba*

- aggiunge al mazzo: **Zappin**

### Prendi l'Elettro

*Promette: un Cucciolo di Elettro*

- aggiunge al mazzo: **Sorc**


---

## Lo scambio

*Dal round 3 in poi.*

> Ti si avvicina un ragazzino: vorrebbe scambiare uno dei suoi Gaiofanamon con uno dei tuoi. Dice che il suo è più forte. Dicono tutti così.

### Accetta lo scambio

*Promette: uno dei tuoi per uno dei suoi*

- scambia una tua carta di gaiofanamon con un'altra dello stesso stadio

### Rifiuta

*Promette: niente*

- Non succede niente.

