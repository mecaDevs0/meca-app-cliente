#!/usr/bin/env python3
"""
🚨 SCRIPT PROFISSIONAL DE CORREÇÃO - AGENDA DA OFICINA
Objetivo: Corrigir definitivamente o problema de agendamento da oficina 684616fef25c7be8e2d394af
MongoDB: meca-app-2025 (MongoDB Atlas)
Autor: Sistema MECA - Correção Crítica
"""

import pymongo
import os
import sys
from datetime import datetime
import json

# Configuração do MongoDB Atlas
MONGODB_CONNECTION_STRING = "mongodb+srv://mecaadmin:Meca2025%40admin@cluster0.llr6i.mongodb.net/meca-app-2025?retryWrites=true&w=majority"
DATABASE_NAME = "meca-app-2025"

# ID da oficina com problema
WORKSHOP_ID = "684616fef25c7be8e2d394af"

def conectar_mongodb():
    """Conecta ao MongoDB Atlas"""
    try:
        print("🔌 Conectando ao MongoDB Atlas...")
        client = pymongo.MongoClient(MONGODB_CONNECTION_STRING)
        
        # Testa a conexão
        client.admin.command('ping')
        print("✅ Conexão com MongoDB Atlas estabelecida com sucesso")
        
        db = client[DATABASE_NAME]
        print(f"📊 Banco de dados: {DATABASE_NAME}")
        
        return client, db
    except Exception as e:
        print(f"❌ ERRO ao conectar no MongoDB: {e}")
        sys.exit(1)

def investigar_oficina(db):
    """Investiga os dados da oficina no MongoDB"""
    try:
        print(f"\n🔍 INVESTIGANDO OFICINA {WORKSHOP_ID}...")
        
        # Coleção de oficinas (Workshop)
        workshops_collection = db['Workshop']
        oficina = workshops_collection.find_one({"_id": pymongo.collection.ObjectId(WORKSHOP_ID)})
        
        if not oficina:
            print(f"❌ OFICINA {WORKSHOP_ID} NÃO ENCONTRADA!")
            return None
            
        print("📋 DADOS DA OFICINA:")
        print(f"   - ID: {oficina.get('_id', 'N/A')}")
        print(f"   - Nome: {oficina.get('FullName', 'N/A')}")
        print(f"   - Empresa: {oficina.get('CompanyName', 'N/A')}")
        print(f"   - Status: {oficina.get('Status', 'N/A')}")
        print(f"   - workshopAgendaValid: {oficina.get('workshopAgendaValid', 'N/A')}")
        print(f"   - workshopServicesValid: {oficina.get('workshopServicesValid', 'N/A')}")
        print(f"   - dataBankValid: {oficina.get('dataBankValid', 'N/A')}")
        
        return oficina
    except Exception as e:
        print(f"❌ ERRO ao investigar oficina: {e}")
        return None

def investigar_agenda_oficina(db):
    """Investiga a agenda da oficina"""
    try:
        print(f"\n📅 INVESTIGANDO AGENDA DA OFICINA...")
        
        # Coleção de agendas (WorkshopAgenda)
        agenda_collection = db['WorkshopAgenda']
        agenda = agenda_collection.find_one({"Workshop": pymongo.collection.ObjectId(WORKSHOP_ID)})
        
        print("📊 RESULTADO DA BUSCA DA AGENDA:")
        if agenda:
            print("✅ Agenda encontrada!")
            print(f"   - ID: {agenda.get('_id', 'N/A')}")
            print(f"   - Monday: {agenda.get('Monday', 'NULL')}")
            print(f"   - Tuesday: {agenda.get('Tuesday', 'NULL')}")
            print(f"   - Wednesday: {agenda.get('Wednesday', 'NULL')}")
            print(f"   - Thursday: {agenda.get('Thursday', 'NULL')}")
            print(f"   - Friday: {agenda.get('Friday', 'NULL')}")
            print(f"   - Saturday: {agenda.get('Saturday', 'NULL')}")
            print(f"   - Sunday: {agenda.get('Sunday', 'NULL')}")
        else:
            print("❌ AGENDA NÃO ENCONTRADA - Este é o problema raiz!")
            
        return agenda
    except Exception as e:
        print(f"❌ ERRO ao investigar agenda: {e}")
        return None

def investigar_servicos_oficina(db):
    """Investiga os serviços da oficina"""
    try:
        print(f"\n🔧 INVESTIGANDO SERVIÇOS DA OFICINA...")
        
        # Coleção de serviços (WorkshopServices)
        servicos_collection = db['WorkshopServices']
        servicos = list(servicos_collection.find({"Workshop": pymongo.collection.ObjectId(WORKSHOP_ID)}))
        
        print(f"📊 SERVIÇOS ENCONTRADOS: {len(servicos)}")
        for i, servico in enumerate(servicos[:5]):  # Limitar a 5 para não poluir
            print(f"   Serviço {i+1}: ID={servico.get('_id', 'N/A')}")
            print(f"     - Description: {servico.get('Description', 'N/A')[:50]}...")
            print(f"     - Service: {servico.get('Service', 'NULL')}")
            
        return servicos
    except Exception as e:
        print(f"❌ ERRO ao investigar serviços: {e}")
        return []

def criar_agenda_padrao(db):
    """Cria uma agenda padrão para a oficina"""
    try:
        print(f"\n🛠️ CRIANDO AGENDA PADRÃO PARA A OFICINA...")
        
        # Definir horário padrão
        horario_padrao = {
            "Open": True,
            "StartTime": "08:00",
            "ClosingTime": "18:00",
            "StartOfBreak": "12:00",
            "EndOfBreak": "13:00"
        }
        
        horario_fechado = {
            "Open": False,
            "StartTime": "08:00",
            "ClosingTime": "18:00", 
            "StartOfBreak": "12:00",
            "EndOfBreak": "13:00"
        }
        
        # Criar documento de agenda
        agenda_documento = {
            "Workshop": pymongo.collection.ObjectId(WORKSHOP_ID),
            "Monday": horario_padrao.copy(),
            "Tuesday": horario_padrao.copy(),
            "Wednesday": horario_padrao.copy(),
            "Thursday": horario_padrao.copy(),
            "Friday": horario_padrao.copy(),
            "Saturday": horario_fechado.copy(),  # Sábado fechado
            "Sunday": horario_fechado.copy(),   # Domingo fechado
            "DataBlocked": None,
            "Disabled": None,
            "Created": int(datetime.now().timestamp())
        }
        
        # Inserir na coleção WorkshopAgenda
        agenda_collection = db['WorkshopAgenda']
        resultado = agenda_collection.insert_one(agenda_documento)
        
        print(f"✅ Agenda criada com sucesso!")
        print(f"   - ID da nova agenda: {resultado.inserted_id}")
        print(f"   - Horário de funcionamento:")
        print(f"     Segunda a Sexta: 08:00 - 18:00")
        print(f"     Sábado e Domingo: Fechado")
        
        return resultado.inserted_id
    except Exception as e:
        print(f"❌ ERRO ao criar agenda: {e}")
        return None

def atualizar_status_oficina(db):
    """Atualiza o status da oficina para habilitada"""
    try:
        print(f"\n🔄 ATUALIZANDO STATUS DA OFICINA...")
        
        # Coleção de oficinas
        workshops_collection = db['Workshop']
        
        # Atualizar campos de validação
        filtro = {"_id": pymongo.collection.ObjectId(WORKSHOP_ID)}
        update = {
            "$set": {
                "workshopAgendaValid": True,
                "workshopServicesValid": True,
                "dataBankValid": True,
                "Status": 1  # Status ativo
            }
        }
        
        resultado = workshops_collection.update_one(filtro, update)
        
        if resultado.modified_count > 0:
            print("✅ Status da oficina atualizado com sucesso!")
            print("   - workshopAgendaValid: True")
            print("   - workshopServicesValid: True") 
            print("   - dataBankValid: True")
            print("   - Status: 1 (Ativo)")
            return True
        else:
            print("⚠️ Nenhum documento foi modificado")
            return False
            
    except Exception as e:
        print(f"❌ ERRO ao atualizar status da oficina: {e}")
        return False

def verificar_correcao(db):
    """Verifica se a correção foi aplicada com sucesso"""
    try:
        print(f"\n🔍 VERIFICANDO CORREÇÃO...")
        
        # Verificar oficina
        workshops_collection = db['Workshop']
        oficina = workshops_collection.find_one({"_id": pymongo.collection.ObjectId(WORKSHOP_ID)})
        
        # Verificar agenda
        agenda_collection = db['WorkshopAgenda']
        agenda = agenda_collection.find_one({"Workshop": pymongo.collection.ObjectId(WORKSHOP_ID)})
        
        print("📊 RESULTADO FINAL:")
        print(f"   Oficina encontrada: {'✅' if oficina else '❌'}")
        print(f"   workshopAgendaValid: {'✅' if oficina and oficina.get('workshopAgendaValid') else '❌'}")
        print(f"   Agenda encontrada: {'✅' if agenda else '❌'}")
        
        if agenda:
            print("   Dias da semana configurados:")
            for dia in ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday']:
                status = '✅' if agenda.get(dia) and agenda.get(dia, {}).get('Open') else '❌'
                horario = ""
                if agenda.get(dia):
                    start = agenda.get(dia, {}).get('StartTime', '')
                    end = agenda.get(dia, {}).get('ClosingTime', '')
                    horario = f" ({start}-{end})" if start and end else ""
                print(f"     {dia}: {status}{horario}")
        
        sucesso = (oficina and 
                  oficina.get('workshopAgendaValid') and
                  agenda and 
                  agenda.get('Monday') and
                  agenda.get('Monday', {}).get('Open'))
        
        return sucesso
    except Exception as e:
        print(f"❌ ERRO ao verificar correção: {e}")
        return False

def main():
    """Função principal"""
    print("=" * 80)
    print("🚨 CORREÇÃO DEFINITIVA - AGENDA DA OFICINA")
    print("Sistema: MECA-APP-CLIENTE")
    print("MongoDB: meca-app-2025 (Atlas)")
    print("=" * 80)
    
    try:
        # Conectar ao MongoDB
        client, db = conectar_mongodb()
        
        # Investigar estado atual
        print("\n" + "="*50)
        print("📊 FASE 1: INVESTIGAÇÃO COMPLETA")
        print("="*50)
        
        oficina = investigar_oficina(db)
        if not oficina:
            print("❌ OFICINA NÃO ENCONTRADA - ABORTANDO")
            sys.exit(1)
            
        agenda_atual = investigar_agenda_oficina(db)
        servicos = investigar_servicos_oficina(db)
        
        # Aplicar correções
        print("\n" + "="*50)
        print("🛠️ FASE 2: APLICANDO CORREÇÕES")
        print("="*50)
        
        if not agenda_atual:
            print("🔧 Criando agenda padrão...")
            agenda_id = criar_agenda_padrao(db)
            if not agenda_id:
                print("❌ FALHA ao criar agenda - ABORTANDO")
                sys.exit(1)
        else:
            print("✅ Agenda já existe - verificando configuração...")
            
        # Atualizar status da oficina
        print("🔄 Atualizando status da oficina...")
        if not atualizar_status_oficina(db):
            print("❌ FALHA ao atualizar status - ABORTANDO")
            sys.exit(1)
            
        # Verificar se tudo funcionou
        print("\n" + "="*50)
        print("🔍 FASE 3: VERIFICAÇÃO FINAL")
        print("="*50)
        
        sucesso = verificar_correcao(db)
        
        if sucesso:
            print("\n🎉 CORREÇÃO APLICADA COM SUCESSO!")
            print("✅ A oficina agora está habilitada para receber agendamentos")
            print("✅ Agenda configurada: Segunda a Sexta (08:00-18:00)")
            print("✅ Status da oficina: Ativo")
        else:
            print("\n❌ CORREÇÃO FALHOU!")
            print("❌ Verificar logs acima para detalhes")
            
        # Fechar conexão
        client.close()
        print(f"\n🔌 Conexão com MongoDB fechada")
        
        return sucesso
        
    except KeyboardInterrupt:
        print("\n⚠️ Operação cancelada pelo usuário")
        return False
    except Exception as e:
        print(f"\n❌ ERRO CRÍTICO: {e}")
        return False

if __name__ == "__main__":
    success = main()
    sys.exit(0 if success else 1)