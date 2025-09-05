import pymongo
from datetime import datetime

# Conecta no MongoDB
client = pymongo.MongoClient("mongodb+srv://mecaadmin:Meca2025%40admin@cluster0.llr6i.mongodb.net/meca-app-2025?retryWrites=true&w=majority")
db = client["meca-app-2025"]

# ID da oficina
workshop_id = "684616fef25c7be8e2d394af"

print(f"🔍 Verificando oficina {workshop_id}...")

# Verificar se agenda existe
agenda_collection = db['WorkshopAgenda']
agenda_existente = agenda_collection.find_one({"Workshop": pymongo.collection.ObjectId(workshop_id)})

if agenda_existente:
    print("✅ Agenda encontrada - atualizando...")
    # Atualizar agenda existente
    update_data = {
        "Monday": {"Open": True, "StartTime": "08:00", "ClosingTime": "18:00", "StartOfBreak": "12:00", "EndOfBreak": "13:00"},
        "Tuesday": {"Open": True, "StartTime": "08:00", "ClosingTime": "18:00", "StartOfBreak": "12:00", "EndOfBreak": "13:00"},
        "Wednesday": {"Open": True, "StartTime": "08:00", "ClosingTime": "18:00", "StartOfBreak": "12:00", "EndOfBreak": "13:00"},
        "Thursday": {"Open": True, "StartTime": "08:00", "ClosingTime": "18:00", "StartOfBreak": "12:00", "EndOfBreak": "13:00"},
        "Friday": {"Open": True, "StartTime": "08:00", "ClosingTime": "18:00", "StartOfBreak": "12:00", "EndOfBreak": "13:00"},
        "Saturday": {"Open": False, "StartTime": "08:00", "ClosingTime": "18:00", "StartOfBreak": "12:00", "EndOfBreak": "13:00"},
        "Sunday": {"Open": False, "StartTime": "08:00", "ClosingTime": "18:00", "StartOfBreak": "12:00", "EndOfBreak": "13:00"}
    }
    agenda_collection.update_one(
        {"Workshop": pymongo.collection.ObjectId(workshop_id)},
        {"$set": update_data}
    )
else:
    print("❌ Agenda não encontrada - criando nova...")
    # Criar nova agenda
    nova_agenda = {
        "Workshop": pymongo.collection.ObjectId(workshop_id),
        "Monday": {"Open": True, "StartTime": "08:00", "ClosingTime": "18:00", "StartOfBreak": "12:00", "EndOfBreak": "13:00"},
        "Tuesday": {"Open": True, "StartTime": "08:00", "ClosingTime": "18:00", "StartOfBreak": "12:00", "EndOfBreak": "13:00"},
        "Wednesday": {"Open": True, "StartTime": "08:00", "ClosingTime": "18:00", "StartOfBreak": "12:00", "EndOfBreak": "13:00"},
        "Thursday": {"Open": True, "StartTime": "08:00", "ClosingTime": "18:00", "StartOfBreak": "12:00", "EndOfBreak": "13:00"},
        "Friday": {"Open": True, "StartTime": "08:00", "ClosingTime": "18:00", "StartOfBreak": "12:00", "EndOfBreak": "13:00"},
        "Saturday": {"Open": False, "StartTime": "08:00", "ClosingTime": "18:00", "StartOfBreak": "12:00", "EndOfBreak": "13:00"},
        "Sunday": {"Open": False, "StartTime": "08:00", "ClosingTime": "18:00", "StartOfBreak": "12:00", "EndOfBreak": "13:00"},
        "DataBlocked": None,
        "Disabled": None,
        "Created": int(datetime.now().timestamp())
    }
    agenda_collection.insert_one(nova_agenda)

# Atualizar status da oficina
workshops_collection = db['Workshop']
workshops_collection.update_one(
    {"_id": pymongo.collection.ObjectId(workshop_id)},
    {"$set": {
        "workshopAgendaValid": True,
        "workshopServicesValid": True,
        "dataBankValid": True,
        "Status": 1
    }}
)

print("✅ Oficina habilitada para agendamentos!")
print("✅ Correção aplicada com sucesso!")

client.close()