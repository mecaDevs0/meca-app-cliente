import pymongo
from datetime import datetime
import sys

try:
    # Conecta MongoDB
    client = pymongo.MongoClient("mongodb+srv://mecaadmin:Meca2025%40admin@cluster0.llr6i.mongodb.net/meca-app-2025?retryWrites=true&w=majority")
    db = client["meca-app-2025"]
    workshop_id = "684616fef25c7be8e2d394af"
    
    # Criar/atualizar agenda
    agenda = {
        "Workshop": pymongo.collection.ObjectId(workshop_id),
        "Monday": {"Open": True, "StartTime": "08:00", "ClosingTime": "18:00", "StartOfBreak": "12:00", "EndOfBreak": "13:00"},
        "Tuesday": {"Open": True, "StartTime": "08:00", "ClosingTime": "18:00", "StartOfBreak": "12:00", "EndOfBreak": "13:00"},
        "Wednesday": {"Open": True, "StartTime": "08:00", "ClosingTime": "18:00", "StartOfBreak": "12:00", "EndOfBreak": "13:00"},
        "Thursday": {"Open": True, "StartTime": "08:00", "ClosingTime": "18:00", "StartOfBreak": "12:00", "EndOfBreak": "13:00"},
        "Friday": {"Open": True, "StartTime": "08:00", "ClosingTime": "18:00", "StartOfBreak": "12:00", "EndOfBreak": "13:00"},
        "Saturday": {"Open": False, "StartTime": "08:00", "ClosingTime": "18:00", "StartOfBreak": "12:00", "EndOfBreak": "13:00"},
        "Sunday": {"Open": False, "StartTime": "08:00", "ClosingTime": "18:00", "StartOfBreak": "12:00", "EndOfBreak": "13:00"},
        "Created": int(datetime.now().timestamp())
    }
    
    # Upsert agenda
    db['WorkshopAgenda'].replace_one({"Workshop": pymongo.collection.ObjectId(workshop_id)}, agenda, upsert=True)
    
    # Atualizar oficina
    db['Workshop'].update_one(
        {"_id": pymongo.collection.ObjectId(workshop_id)},
        {"$set": {"workshopAgendaValid": True, "workshopServicesValid": True, "dataBankValid": True, "Status": 1}}
    )
    
    print("SUCESSO: Oficina habilitada!")
    client.close()
except Exception as e:
    print(f"ERRO: {e}")
    sys.exit(1)