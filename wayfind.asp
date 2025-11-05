<% Option Explicit %>
<%
' --- CONFIGURAÇÕES DO CABEÇALHO ---
Response.AddHeader "Access-Control-Allow-Origin", "https://catalogo.usdb.uminho.pt"
Response.AddHeader "X-Frame-Options", "ALLOW-FROM https://catalogo.usdb.uminho.pt"
On Error Resume Next 
%>

<%
' --- DECLARAÇÃO DE VARIÁVEIS ---
Dim erroBD, erroBib, erroPlanta, imagem, infobib, infobib_en, biblio, biblio_en
Dim infos, infos_en, url, local, local_en, url_en 
Dim cota, spacePos, bib, cdu, cleanCdu
Dim objConn, objRS, DSN, mySQL, count, bestMatch, bestMatchLength, i, partialCdu
Dim fs, cduFound 

' --- INICIALIZAÇÃO DE VARIÁVEIS ---
erroBD = ""
erroBib = ""
erroPlanta = ""
imagem = ""
infobib = ""
infobib_en = ""
biblio = ""
biblio_en = ""
infos = ""
infos_en = ""
url = ""
url_en = ""
local = ""
local_en = ""
cduFound = False 

' --- OBTENCÃO DA COTA VIA QUERYSTRING ---
cota = Trim(Request.QueryString("cota"))

' --- CONFIGURAÇÃO DA CONEXÃO À BASE DE DADOS ---
Set objConn = Server.CreateObject("ADODB.Connection")
DSN = "Driver={SQL Server};Server=SEU_SERVIDOR_AQUI;Database=SUA_BD_AQUI;UID=SEU_UTILIZADOR_AQUI;PWD=SUA_PASSWORD_AQUI"
objConn.Open(DSN)

If objConn.State = 1 Then
	' --- 1. PROCESSAMENTO INICIAL DA COTA (SIGLA E CDU) ---
    spacePos = InStr(cota, " ")
    If spacePos > 0 Then
	' Se a cota tem um espaço (ex: BGUM 621.3)
        bib = Replace(Left(cota, spacePos - 1), "'", "''")
        cdu = Trim(Mid(cota, spacePos + 1))
        
        cleanCdu = cdu
        If InStr(cleanCdu, "-") > 0 Then
		' Limpa o sufixo (ex: 621.3 - c => 621.3)
            cleanCdu = Trim(Left(cleanCdu, InStr(cleanCdu, "-") - 1))
        End If
    Else
		' Se a cota é só a sigla (ex: BGUM)
        bib = Replace(cota, "'", "''")
        cdu = ""
        cleanCdu = ""
    End If
    
	' --- 2. OBTÉM INFORMAÇÕES DA SUB-BIBLIOTECA (sub-bibs) ---
    mySQL = "SELECT * FROM [dbo].[sub-bibs] WHERE sigla = '" & bib & "'"
    
    Set objRS = Server.CreateObject("ADODB.Recordset")
    objRS.Open mySQL, objConn, 3, 3
    
    If Not objRS.EOF Then
        biblio = objRS("nome")
        biblio_en = objRS("nome_en")
        infos = objRS("info")
        infos_en = objRS("info_en")
        url = objRS("url")
        local = objRS("local")
        local_en = objRS("local_en")
    Else
		' Regista erro e define mensagem
        erroBib = "Sub-biblioteca não encontrada"
        objConn.Execute "INSERT INTO [dbo].[erros] VALUES ('" & Now() & "','" & cota & "','','Sub-biblioteca não existe')"
    End If
    objRS.Close
    
	' --- 3. PROCURA PELA MELHOR CORRESPONDÊNCIA DA CDU (cotas) ---
    If erroBib = "" Then
        If cleanCdu <> "" Then
            mySQL = "SELECT * FROM [dbo].[cotas] WHERE sigla = '" & bib & "'"
            Set objRS = Server.CreateObject("ADODB.Recordset")
            objRS.Open mySQL, objConn, 3, 3
            count = objRS.RecordCount
            
            If count > 0 Then
                bestMatch = ""
                bestMatchLength = 0
                
				' Itera a CDU da notação mais curta para a mais longa
                For i = 1 To Len(cleanCdu)
                    partialCdu = Left(cleanCdu, i)
                    objRS.Filter = "cota = '" & partialCdu & "'"
                    
                    If objRS.RecordCount > 0 Then
                        If Len(partialCdu) >= bestMatchLength Then
						' Encontrada uma correspondência mais longa
                            bestMatch = partialCdu
                            bestMatchLength = Len(partialCdu)
                            cduFound = True
                            infobib = " " & objRS("info")
                            infobib_en = " " & objRS("info_en")
                            imagem = objRS("planta")
                        End If
                    End If
                Next
                
				' Fallback: Se não houve correspondência exata, tenta a correspondência parcial (LIKE)
                If Not cduFound Then
                    For i = Len(cleanCdu) To 1 Step -1
                        partialCdu = Left(cleanCdu, i)
                        objRS.Filter = "cota LIKE '" & partialCdu & "%'"
                        
                        If objRS.RecordCount > 0 Then
                            objRS.MoveFirst
                            bestMatch = partialCdu
                            cduFound = True
                            infobib = " " & objRS("info")
                            infobib_en = " " & objRS("info_en")
                            imagem = objRS("planta")
                            Exit For
                        End If
                    Next
                End If
            End If
            
            objRS.Close
        End If
        
		' --- 4. FALLBACK PARA IMAGEM GENÉRICA (SE CDU NÃO ENCONTROU NADA) ---
        If imagem = "" And erroBib = "" Then
            
			' Tenta encontrar uma entrada sem CDU específica (cota IS NULL)
            mySQL = "SELECT TOP 1 * FROM [dbo].[cotas] WHERE sigla = '" & bib & "' AND (cota IS NULL OR cota = '') ORDER BY id DESC"
            Set objRS = Server.CreateObject("ADODB.Recordset")
            objRS.Open mySQL, objConn, 3, 3

            If Not objRS.EOF Then
                infobib = " " & objRS("info")
                infobib_en = " " & objRS("info_en")
                imagem = objRS("planta")
            Else
                objRS.Close
                mySQL = "SELECT TOP 1 * FROM [dbo].[cotas] WHERE sigla = '" & bib & "' ORDER BY id ASC"
                objRS.Open mySQL, objConn, 3, 3

                If Not objRS.EOF Then
                    infobib = " " & objRS("info")
                    infobib_en = " " & objRS("info_en")
                    imagem = objRS("planta")
                End If
            End If
            objRS.Close
        End If
        
    End If 
    
	' --- 5. VERIFICAÇÃO DO FICHEIRO E PINO GENÉRICO ---
    If imagem <> "" Then
        Set fs = Server.CreateObject("Scripting.FileSystemObject")
        If NOT fs.FileExists(Server.MapPath("plantas/" & imagem)) Then
            erroPlanta = "Ficheiro de imagem não encontrado: " & imagem
            imagem = "" 
        End If
        Set fs = Nothing
    End If
    
	' Usa o pin genérico se não encontrou imagem mas a biblioteca existe
    If imagem = "" And erroBib = "" Then
        erroPlanta = "pin.png" 
    End If
    
	' --- 6. FECHO DE CONEXÕES ---
    Set objRS = Nothing
    objConn.Close
    Set objConn = Nothing
    On Error GoTo 0
Else
    erroBD = "Não é possível ligar à base de dados"
End If
%>

<!DOCTYPE html>
<html>
<head>
    <title></title>
    
    <style>
        body {
            font-family: Arial;
            margin: 0;
            padding: 0;
            color: #8C8C8C;
        }
        
        a {
            color: unset;
			color: #a71a21;
        }

        .container {
            width: 100%;
            margin: 0 auto;
            text-align: center;
        }
        .location-image {
            max-height: 450px;
            margin-top: 0px;
            border: 0px solid #ddd;  
        }
        .error-image {
            max-width: 50px; 
            margin-top: 0px;
            border: 0px solid #ddd;  
        }
        .info-message {
            color: #006600;
            margin: 20px 0;
            padding: 10px;
            background-color: #eeffee;
            border: 1px solid #ccffcc;
            border-radius: 4px;
        }
        .bib_sigla {            
            font-weight: bold;
            font-size: 1.7rem;
            margin-top: 25px;
            display:inline-block;
        }
        .bib_pt {
            font-weight: bold;
            font-size: 1.1rem;
            margin-top: 5px;
            display:inline-block;
        }
        
        .bib_en {
            font-size: 1.1rem;
            font-style: italic;
            margin-top: 5px;
            display:inline-block;
        }
        .infos {
            font-size: 1.1rem;
            margin-top: 5px;
            display:inline-block;
        }
        .infos_en {
            font-size: 1.1rem;
            font-style: italic;
            margin-top: 5px;
            display:inline-block;
        }
        
    </style>
</head>
<body>
    <div class="container">
        <span class="bib_sigla"><% Response.Write(bib) %></span><br>
        <span class="bib_pt"><% Response.Write(biblio) %><% Response.Write(infobib) %></span><br>
        <span class="bib_en"><% Response.Write(biblio_en) %><% Response.Write(infobib_en) %></span><br>
        
        
        
        <% If imagem <> "" Then %>
            <br><img src="plantas/<% Response.Write(imagem) %>" alt="Planta de localização" class="location-image">
        <% ElseIf infobib <> "" Then %>
            <div class="info-message">
                <% Response.Write(infobib) %></p>
            </div>
        <% End If %>
        
        
        <% If erroPlanta <> "" Then %>
            <div>
                <br><br><img class="error-image" src="plantas/<% Response.Write(erroPlanta) %>" alt="Planta não encontrada" >
            </div>
        <% End If %>
        
        
        <% If erroBD <> "" Then %>
            <div class="error">
                <p><% Response.Write(erroBD) %></p>
            </div>
        <% End If %>
        
        
        <% If erroBib <> "" Then %>
            <div class="error">
                <p><% Response.Write(erroBib) %></p>
            </div>
        <% End If %>
        
        <br><span class="bib_pt"><a target=_blank href="<% Response.Write(url) %>"><% Response.Write(local) %></a></span>
        <br><span class="bib_en"><% Response.Write(local_en) %></span>
        
        
        <% If infos <> "" Then %>
            <br><br><br><span class="infos"><% Response.Write(infos) %></span>
            <br><span class="infos_en"><% Response.Write(infos_en) %></span>
        <% End If %>
        
    </div>
</body>
</html>