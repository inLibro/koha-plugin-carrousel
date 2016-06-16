<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform">
<xsl:output encoding="UTF-8"/>

<xsl:template match="/">
    <xsl:apply-templates/>
</xsl:template>

<xsl:template match="opt">
  <html>
  <head>
  <style>
.description{
    background-color: #EDEDF7;
    text-align:left;
    padding-bottom: 7px;
    padding-left: 10px;
}

.head{
    text-align:left;
    width: 60%;
    padding-bottom: 15px;
    padding-top: 15px;
}

.second_head{
    padding-bottom: 10px;
    padding-top:10px;
    padding-left: 10px;
}

.cell{
    text-align:right;
    border: 1px solid black;
    width: 10%;
    padding-right: 5px;
}

table {
    border-collapse: collapse;
    width: 100%;
}

.cell_empty{
    background-color: #EDEDF7;
    width: 10%;
}
  </style>
  </head>
  <body>
    <h1>2 - Collection - Fonds</h1>
    <table>
      <tr>
        <th class="head">2.1 - Livres (imprimés)</th>
        <th>Adultes</th>
        <th>Enfants</th>
        <th>Non codées</th>
        <th>Total</th>
      </tr>
      <tr>
        <td class="description">1- Nombre d'unités matérielles :</td>
        <td class="cell"><xsl:value-of select="fundPrintedBook/numAdultUnit"/></td>
        <td class="cell"><xsl:value-of select="fundPrintedBook/numChildUnit"/></td>
        <td class="cell"><xsl:value-of select="fundPrintedBook/numNocodedUnit"/></td>
         <td class="cell" ><xsl:value-of select="fundPrintedBook/numNocodedUnit + fundPrintedBook/numChildUnit + fundPrintedBook/numAdultUnit"/></td>
      </tr>
      <tr>
        <td class="description">2- Nombre de titres :</td>
        <td class="cell"><xsl:value-of select="fundPrintedBook/numAdultTitle"/></td>
        <td class="cell"><xsl:value-of select="fundPrintedBook/numChildTitle"/></td>
        <td class="cell"><xsl:value-of select="fundPrintedBook/numNocodedTitle"/></td>
        <td class="cell"><xsl:value-of select="fundPrintedBook/numNocodedTitle + fundPrintedBook/numChildTitle + fundPrintedBook/numAdultTitle"/></td>
     </tr>
     <tr>
        <td class="description" >3- Nombre d'unités matérielles publiées en français :</td>
        <td class="cell_empty"></td>
        <td class="cell_empty"></td>
        <td class="cell_empty"></td>
        <td class="cell"><xsl:value-of select="fundPrintedBook/numPubFr"/></td>
      </tr>
      <tr>
        <td class="description" >4- Nombre d'unités matérielles publiées en anglais :</td>
        <td class="cell_empty"></td>
        <td class="cell_empty"></td>
        <td class="cell_empty"></td>
        <td class="cell"><xsl:value-of select="fundPrintedBook/numPubEng"/></td>
      </tr>
      <tr>
        <td class="description" >5- Nombre d'unités matérielles publiées dans une autre langue :</td>
        <td class="cell_empty"></td>
        <td class="cell_empty"></td>
        <td class="cell_empty"></td>
        <td class="cell"><xsl:value-of select="fundPrintedBook/numPubOther"/></td>
      </tr>
      <tr>
        <td class="description">6- Nombre d'unités matérielles publiées au Québec :</td>
        <td class="cell_empty"></td>
        <td class="cell_empty"></td>
        <td class="cell_empty"></td>
        <td class="cell"><xsl:value-of select="fundPrintedBook/numPubQuc"/></td>
      </tr>
    </table>

    <table>
      <tr>
        <th class="head">2.2 - Documents audiovisuels</th>
      </tr>
      <tr>
        <td class="second_head">Documents sonores : musique</td>
      </tr>
      <tr>
        <td class="description">1- Nombre d'unités matérielles :</td>
        <td class="cell_empty"></td>
        <td class="cell_empty"></td>
        <td class="cell_empty"></td>
        <td class="cell"><xsl:value-of select="fundAudioVisual/numSRMusicUnit"/></td>
      </tr>
      <tr>
        <td class="description">2- Nombre d'unités matérielles produites au Québec :</td>
        <td class="cell_empty"></td>
        <td class="cell_empty"></td>
        <td class="cell_empty"></td>
        <td class="cell"><xsl:value-of select="fundAudioVisual/numSRMusicProdQuc"/></td>
      </tr>
      <tr>
        <td class="description">3- Nombre de titres :</td>
        <td class="cell_empty"></td>
        <td class="cell_empty"></td>
        <td class="cell_empty"></td>
        <td class="cell"><xsl:value-of select="fundAudioVisual/numSRMusicTitle"/></td>
      </tr>
      <tr>
        <td class="second_head">Documents sonores : livres audio</td>
      </tr>
      <tr>
        <td class="description">4- Nombre d'unités matérielles :</td>
        <td class="cell_empty"></td>
        <td class="cell_empty"></td>
        <td class="cell_empty"></td>
        <td class="cell"><xsl:value-of select="fundAudioVisual/numSRBookUnit"/></td>
      </tr>
      <tr>
        <td class="description">5- Nombre d'unités matérielles produites au Québec :</td>
        <td class="cell_empty"></td>
        <td class="cell_empty"></td>
        <td class="cell_empty"></td>
        <td class="cell"><xsl:value-of select="fundAudioVisual/numSRBookProdQuc"/></td>
      </tr>
      <tr>
        <td class="description">6- Nombre de titres :</td>
        <td class="cell_empty"></td>
        <td class="cell_empty"></td>
        <td class="cell_empty"></td>
        <td class="cell"><xsl:value-of select="fundAudioVisual/numSRBookTitle"/></td>
      </tr>
      <tr>
        <td class="second_head">Documents audiovisuels</td>
      </tr>
      <tr>
        <td class="description">7- Films - Nombre d'unités matérielles :</td>
        <td class="cell_empty"></td>
        <td class="cell_empty"></td>
        <td class="cell_empty"></td>
        <td class="cell"><xsl:value-of select="fundAudioVisual/numSRCombUnit"/></td>
      </tr>
      <tr>
        <td class="description">8- Films - Nombre d'unités matérielles produites au Québec :</td>
        <td class="cell_empty"></td>
        <td class="cell_empty"></td>
        <td class="cell_empty"></td>
        <td class="cell"><xsl:value-of select="fundAudioVisual/numSRCombProdQuc"/></td>
      </tr>
      <tr>
        <td class="description">9- Films - Nombre de titres :</td>
        <td class="cell_empty"></td>
        <td class="cell_empty"></td>
        <td class="cell_empty"></td>
        <td class="cell"><xsl:value-of select="fundAudioVisual/numSRCombTitle"/></td>
      </tr>
       <tr>
        <td class="description">10- Jeux vidéo - Nombre d'unités matérielles :</td>
        <td class="cell_empty"></td>
        <td class="cell_empty"></td>
        <td class="cell_empty"></td>
        <td class="cell"><xsl:value-of select="fundAudioVisual/numSRGameUnit"/></td>
      </tr>
      <tr>
        <td class="description">11- Jeux vidéo - Nombre d'unités matérielles produites au Québec :</td>
        <td class="cell_empty"></td>
        <td class="cell_empty"></td>
        <td class="cell_empty"></td>
        <td class="cell"><xsl:value-of select="fundAudioVisual/numSRGameProdQuc"/></td>
      </tr>
      <tr>
        <td class="description">12- Jeux vidéo - Nombre de titres :</td>
        <td class="cell_empty"></td>
        <td class="cell_empty"></td>
        <td class="cell_empty"></td>
        <td class="cell"><xsl:value-of select="fundAudioVisual/numSRGameTitle"/></td>
      </tr>
    </table>

    <table>
      <tr>
        <th class="head">2.3 - Collection électronique</th>
      </tr>
      <tr>
        <td class="second_head">Bases de données</td>
      </tr>
      <tr>
        <td class="description">1- Nombre de titres :</td>
        <td class="cell_empty"></td>
        <td class="cell_empty"></td>
        <td class="cell_empty"></td>
        <td class="cell">N/A</td>
      </tr>
      <tr>
        <td class="description">2- Nombre de titres produits au Québec :</td>
        <td class="cell_empty"></td>
        <td class="cell_empty"></td>
        <td class="cell_empty"></td>
        <td class="cell">N/A</td>
      </tr>
      <tr>
        <td class="second_head">Publications en série électroniques</td>
      </tr>
      <tr>
        <td class="description">3- Nombre de titres :</td>
        <td class="cell_empty"></td>
        <td class="cell_empty"></td>
        <td class="cell_empty"></td>
        <td class="cell"><xsl:value-of select="fundElectronicSerial/numTitle"/></td>
      </tr>
      <tr>
        <td class="description">4- Nombre de titres publiés au Québec :</td>
        <td class="cell_empty"></td>
        <td class="cell_empty"></td>
        <td class="cell_empty"></td>
        <td class="cell"><xsl:value-of select="fundElectronicSerial/numProdQuc"/></td>
      </tr>
      <tr>
        <td class="second_head">Documents numériques</td>
      </tr>
      <tr>
        <td class="description">5- Livres électroniques - nombre de titres :</td>
        <td class="cell_empty"></td>
        <td class="cell_empty"></td>
        <td class="cell_empty"></td>
        <td class="cell"><xsl:value-of select="fundElectronicBook/numTitle"/></td>
      </tr>
      <tr>
        <td class="description">6- Livres électroniques - nombre de titres publiés au Québec :</td>
        <td class="cell_empty"></td>
        <td class="cell_empty"></td>
        <td class="cell_empty"></td>
        <td class="cell"><xsl:value-of select="fundElectronicBook/numProdQuc"/></td>
      </tr>
      <tr>
        <td class="description">7- Livre électronique - nombre d'exemplaires :</td>
        <td class="cell_empty"></td>
        <td class="cell_empty"></td>
        <td class="cell_empty"></td>
        <td class="cell"><xsl:value-of select="fundElectronicBook/numItem"/></td>
      </tr>
      <tr>
        <td class="description">8- Livre électronique - nombre d'exemplaires publiés au québec :</td>
        <td class="cell_empty"></td>
        <td class="cell_empty"></td>
        <td class="cell_empty"></td>
        <td class="cell"><xsl:value-of select="fundElectronicBook/numItemQuc"/></td>
      </tr>
      <tr>
        <td class="description">9- Autres documents numériques - nombre de titres :</td>
        <td class="cell_empty"></td>
        <td class="cell_empty"></td>
        <td class="cell_empty"></td>
        <td class="cell"><xsl:value-of select="fundElectronicOther/numTitle"/></td>
      </tr>
      <tr>
        <td class="description">10- Autres documents numériques - nombre de titres produits au Québec :</td>
        <td class="cell_empty"></td>
        <td class="cell_empty"></td>
        <td class="cell_empty"></td>
        <td class="cell"><xsl:value-of select="fundElectronicOther/numProdQuc"/></td>
      </tr>
    </table>
    <table>
      <tr>
        <th class="head">2.4 - Autres documents</th>
      </tr>
      <tr>
        <td class="description">1- Nombre d'unités matérielles</td>
        <td class="cell_empty"></td>
        <td class="cell_empty"></td>
        <td class="cell_empty"></td>
        <td class="cell"><xsl:value-of select="fundOtherDocument/numUnit"/></td>
      </tr>
    </table>

    <h1>3. Collection - Acquisitions</h1>
    <table>
      <tr>
        <th class="head">3.1 - Livres (imprimés)</th>
      </tr>
      <tr>
        <td class="description">1- Nombre d'unités matérielles :</td>
        <td class="cell_empty"></td>
        <td class="cell_empty"></td>
        <td class="cell_empty"></td>
        <td class="cell"><xsl:value-of select="acqPrintedBook/numUnitOutAcq"/></td>
      </tr>
      <tr>
        <td class="description">2- Nombre d'unités matérielles publiées au Québec :</td>
        <td class="cell_empty"></td>
        <td class="cell_empty"></td>
        <td class="cell_empty"></td>
        <td class="cell"><xsl:value-of select="acqPrintedBook/numProdQucOutAcq"/></td>
      </tr>
    </table>

    <table>
      <tr>
        <th class="head">3.2 - Publications en série en cours (imprimées)</th>
      </tr>
      <tr>
        <td class="description">1- Nombre d'abonnements :</td>
        <td class="cell_empty"></td>
        <td class="cell_empty"></td>
        <td class="cell_empty"></td>
        <td class="cell"><xsl:value-of select="acqPrintedSerial/numUnit"/></td>
      </tr>
      <tr>
        <td class="description">2- Nombre d'abonnements publiés au Québec :</td>
        <td class="cell_empty"></td>
        <td class="cell_empty"></td>
        <td class="cell_empty"></td>
        <td class="cell"><xsl:value-of select="acqPrintedSerial/numPubQuc"/></td>
      </tr>
      <tr>
        <td class="description">3- Nombre de titres :</td>
        <td class="cell_empty"></td>
        <td class="cell_empty"></td>
        <td class="cell_empty"></td>
        <td class="cell"><xsl:value-of select="acqPrintedSerial/numTitle"/></td>
      </tr>
    </table>

    <table>
      <tr>
        <th class="head">3.3 - Documents audiovisuels</th>
      </tr>
      <tr>
        <td class="description">1- Nombre d'unités matérielles :</td>
        <td class="cell_empty"></td>
        <td class="cell_empty"></td>
        <td class="cell_empty"></td>
        <td class="cell"><xsl:value-of select="acqAudioVisual/numUnitOutAcq"/></td>
      </tr>
    </table>

 <table>
      <tr>
        <th class="head">3.4 - Collection électronique</th>
      </tr>
      <tr>
        <td class="second_head">Bases de données</td>
      </tr>
      <tr>
        <td class="description">1- Nombre de titres :</td>
        <td class="cell_empty"></td>
        <td class="cell_empty"></td>
        <td class="cell_empty"></td>
        <td class="cell">N/A</td>
      </tr>
      <tr>
        <td class="second_head">Publications en série électroniques</td>
      </tr>
      <tr>
        <td class="description">2- Nombre de titres :</td>
        <td class="cell_empty"></td>
        <td class="cell_empty"></td>
        <td class="cell_empty"></td>
        <td class="cell"><xsl:value-of select="acqElectronicSerial/numTitle"/></td>
      </tr>
      <tr>
        <td class="description">3- Nombre de titres publiés au Québec:</td>
        <td class="cell_empty"></td>
        <td class="cell_empty"></td>
        <td class="cell_empty"></td>
        <td class="cell"><xsl:value-of select="acqElectronicSerial/numTitleQuc"/></td>
      </tr>
      <tr>
        <td class="second_head">Documents numériques</td>
      </tr>
      <tr>
        <td class="description">4- Livres numériques - nombre de titres :</td>
        <td class="cell_empty"></td>
        <td class="cell_empty"></td>
        <td class="cell_empty"></td>
        <td class="cell"><xsl:value-of select="acqElectronicBook/numTitle"/></td>
      </tr>
      <tr>
        <td class="description">5- Livres numériques - nombre d'exemplaires :</td>
        <td class="cell_empty"></td>
        <td class="cell_empty"></td>
        <td class="cell_empty"></td>
        <td class="cell"><xsl:value-of select="acqElectronicBook/numItem"/></td>
      </tr>
      <tr>
        <td class="description">6- Livres numériques - nombre de titres publiés au Québec :</td>
        <td class="cell_empty"></td>
        <td class="cell_empty"></td>
        <td class="cell_empty"></td>
        <td class="cell"><xsl:value-of select="acqElectronicBook/numTitleQuc"/></td>
      </tr>
      <tr>
        <td class="description">7- Livres numériques - nombre de d'exemplaires publiés au Québec :</td>
        <td class="cell_empty"></td>
        <td class="cell_empty"></td>
        <td class="cell_empty"></td>
        <td class="cell"><xsl:value-of select="acqElectronicBook/numItemQuc"/></td>
      </tr>
      <tr>
        <td class="description">8- Autres documents numériques - nombre de titres :</td>
        <td class="cell_empty"></td>
        <td class="cell_empty"></td>
        <td class="cell_empty"></td>
        <td class="cell"><xsl:value-of select="acqElectronicOther/numTitle"/></td>
      </tr>
    </table>
    <table>
      <tr>
        <th class="head">3.5 - Autres documents</th>
      </tr>
      <tr>
        <td class="description">1- Nombre d'unités matérielles :</td>
        <td class="cell_empty"></td>
        <td class="cell_empty"></td>
        <td class="cell_empty"></td>
        <td class="cell"><xsl:value-of select="acqOtherDocument/numUnit"/></td>
      </tr>
    </table>
    <table>
      <tr>
        <th class="head">3.6 - Retraits</th>
      </tr>
      <tr>
        <td class="description">1- Nombre d'unités matérielles :</td>
        <td class="cell_empty"></td>
        <td class="cell_empty"></td>
        <td class="cell_empty"></td>
        <td class="cell"><xsl:value-of select="acqElimination/numUnit"/></td>
      </tr>
    </table>
    <h1>4- Services et usage</h1>
    <table>
      <tr>
        <th class="head">4.1 - Usagers</th>
      </tr>
      <tr>
        <td class="description">1- Nombre d'usagers inscrits - adultes :</td>
        <td class="cell_empty"></td>
        <td class="cell_empty"></td>
        <td class="cell_empty"></td>
        <td class="cell"><xsl:value-of select="useNumRegistredUsers/numAdult"/></td>
      </tr>
      <tr>
        <td class="description">2- Nombre d'usagers inscrits - enfants :</td>
        <td class="cell_empty"></td>
        <td class="cell_empty"></td>
        <td class="cell_empty"></td>
        <td class="cell"><xsl:value-of select="useNumRegistredUsers/numChild"/></td>
      </tr>
      <tr>
        <td class="description">3- Nombre d'usagers inscrits - féminins :</td>
        <td class="cell_empty"></td>
        <td class="cell_empty"></td>
        <td class="cell_empty"></td>
        <td class="cell"><xsl:value-of select="useNumRegistredUsers/numFemale"/></td>
      </tr>
      <tr>
        <td class="description">4- Nombre d'usagers inscrits - masculins :</td>
        <td class="cell_empty"></td>
        <td class="cell_empty"></td>
        <td class="cell_empty"></td>
        <td class="cell"><xsl:value-of select="useNumRegistredUsers/numMale"/></td>
      </tr>
      <tr>
        <td class="description">5- Nombre d'usagers inscrits - institutions :</td>
        <td class="cell_empty"></td>
        <td class="cell_empty"></td>
        <td class="cell_empty"></td>
        <td class="cell"><xsl:value-of select="useNumRegistredUsers/numInstitution"/></td>
      </tr>
      <tr>
        <td class="description">6- Nombre d'usagers inscrits - total :</td>
        <td class="cell_empty"></td>
        <td class="cell_empty"></td>
        <td class="cell_empty"></td>
        <td class="cell"><xsl:value-of select="useNumRegistredUsers/numFemale + useNumRegistredUsers/numMale + useNumRegistredUsers/numInstitution"/></td>
      </tr>
      <tr>
        <td class="description">7- Nombre d'emprunteurs actifs :</td>
        <td class="cell_empty"></td>
        <td class="cell_empty"></td>
        <td class="cell_empty"></td>
        <td class="cell"><xsl:value-of select="useNumRegistredUsers/numActives"/></td>
      </tr>
    </table>
    <table>
      <tr>
        <th class="head">4.2 - Prêts</th>
      </tr>
      <tr>
        <td class="head">Prêts aux usagers - nombre d'unités matérielles</td>
        <td style="text-align:center;">Adultes</td>
        <td style="text-align:center;">Enfants</td>
        <td style="text-align:center;">Total</td>
      </tr>
      <tr>
        <td class="description">1- Livres (imprimés) :</td>
        <td class="cell"><xsl:value-of select="useNumLoanUnit/numUnitPrintedBookAdult"/></td>
        <td class="cell"><xsl:value-of select="useNumLoanUnit/numUnitPrintedBookChild"/></td>
        <td class="cell"><xsl:value-of select="useNumLoanUnit/numUnitPrintedBookChild + useNumLoanUnit/numUnitPrintedBookAdult"/></td>
      </tr>
      <tr>
        <td class="description">2 - Publications en série (imprimées) :</td>
        <td class="cell"><xsl:value-of select="useNumLoanUnit/numUnitPrintedSerialAdult"/></td>
        <td class="cell"><xsl:value-of select="useNumLoanUnit/numUnitPrintedSerialChild"/></td>
        <td class="cell"><xsl:value-of select="useNumLoanUnit/numUnitPrintedSerialChild + useNumLoanUnit/numUnitPrintedSerialAdult"/></td>
      </tr>
      <tr>
        <td class="description">3- Documents audiovisuels :</td>
        <td class="cell"><xsl:value-of select="useNumLoanUnit/numUnitAudioVisualAdult"/></td>
        <td class="cell"><xsl:value-of select="useNumLoanUnit/numUnitAudioVisualChild"/></td>
        <td class="cell"><xsl:value-of select="useNumLoanUnit/numUnitAudioVisualChild + useNumLoanUnit/numUnitAudioVisualAdult"/></td>
      </tr>
      <tr>
        <td class="description">4- Livres numériques :</td>
        <td class="cell"><xsl:value-of select="useNumLoanUnit/numUnitDigitalDocumentAdult"/></td>
        <td class="cell"><xsl:value-of select="useNumLoanUnit/numUnitDigitalDocumentChild"/></td>
        <td class="cell"><xsl:value-of select="useNumLoanUnit/numUnitDigitalDocumentAdult + useNumLoanUnit/numUnitDigitalDocumentChild"/></td>
      </tr>
      <tr>
        <td class="description">5- Autres documents numériques :</td>
        <td class="cell"><xsl:value-of select="useNumLoanUnit/numUnitOtherDigitalDocumentAdult"/></td>
        <td class="cell"><xsl:value-of select="useNumLoanUnit/numUnitOtherDigitalDocumentChild"/></td>
        <td class="cell"><xsl:value-of select="useNumLoanUnit/numUnitOtherDigitalDocumentAdult + useNumLoanUnit/numUnitOtherDigitalDocumentChild"/></td>
      </tr>
      <tr>
        <td class="description">6- Autres documents :</td>
        <td class="cell"><xsl:value-of select="useNumLoanUnit/numUnitOtherDocumentAdult"/></td>
        <td class="cell"><xsl:value-of select="useNumLoanUnit/numUnitOtherDocumentChild"/></td>
        <td class="cell"><xsl:value-of select="useNumLoanUnit/numUnitOtherDocumentAdult + useNumLoanUnit/numUnitOtherDocumentChild"/></td>
      </tr>
      <tr>
        <td class="description">7- Tous les documents :</td>
        <td class="cell"><xsl:value-of select="useNumLoanUnit/numUnitPrintedBookAdult + useNumLoanUnit/numUnitPrintedSerialAdult + useNumLoanUnit/numUnitAudioVisualAdult + useNumLoanUnit/numUnitDigitalDocumentAdult + useNumLoanUnit/numUnitOtherDocumentAdult"/></td>
        <td class="cell"><xsl:value-of select="useNumLoanUnit/numUnitPrintedBookChild + useNumLoanUnit/numUnitPrintedSerialChild + useNumLoanUnit/numUnitAudioVisualChild + useNumLoanUnit/numUnitDigitalDocumentChild + useNumLoanUnit/numUnitOtherDocumentChild"/></td>
        <td class="cell"><xsl:value-of select="useNumLoanUnit/numUnitPrintedBookAdult + useNumLoanUnit/numUnitPrintedSerialAdult + useNumLoanUnit/numUnitAudioVisualAdult + useNumLoanUnit/numUnitDigitalDocumentAdult + useNumLoanUnit/numUnitOtherDocumentAdult
        + useNumLoanUnit/numUnitPrintedBookChild + useNumLoanUnit/numUnitPrintedSerialChild + useNumLoanUnit/numUnitAudioVisualChild + useNumLoanUnit/numUnitDigitalDocumentChild + useNumLoanUnit/numUnitOtherDocumentChild"/></td>
      </tr>
      <tr>
        <td class="head">Renouvellement</td>
      </tr>
      <tr>
        <td class="description">8- Nombre de renouvellement</td>
        <td class="cell_empty"></td>
        <td class="cell_empty"></td>
        <td class="cell"><xsl:value-of select="useNumRenewal"/></td>
      </tr>
    </table>
<br/><br/>
  </body>
  </html>
</xsl:template>
</xsl:stylesheet>
