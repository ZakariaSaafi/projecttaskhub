// scripts/init-mongo.js
// Initialisation MongoDB pour TaskService

// Créer la base de données taskdb
db = db.getSiblingDB('taskdb');

// Créer un utilisateur pour l'application
db.createUser({
    user: "taskservice",
    pwd: "taskservice123",
    roles: [
        {
            role: "readWrite",
            db: "taskdb"
        }
    ]
});

// Créer la collection tasks avec validation
db.createCollection("tasks", {
    validator: {
        $jsonSchema: {
            bsonType: "object",
            required: ["title", "projectId", "status", "priority"],
            properties: {
                title: {
                    bsonType: "string",
                    description: "Le titre est obligatoire"
                },
                description: {
                    bsonType: "string"
                },
                projectId: {
                    bsonType: "long",
                    description: "L'ID du projet est obligatoire"
                },
                status: {
                    enum: ["TODO", "IN_PROGRESS", "REVIEW", "DONE", "CANCELLED"],
                    description: "Le statut doit être valide"
                },
                priority: {
                    enum: ["LOW", "MEDIUM", "HIGH", "URGENT"],
                    description: "La priorité doit être valide"
                },
                assignedTo: {
                    bsonType: "string"
                },
                dueDate: {
                    bsonType: "date"
                },
                createdAt: {
                    bsonType: "date"
                },
                updatedAt: {
                    bsonType: "date"
                }
            }
        }
    }
});

// Créer des index pour améliorer les performances
db.tasks.createIndex({ "projectId": 1 });
db.tasks.createIndex({ "assignedTo": 1 });
db.tasks.createIndex({ "status": 1 });
db.tasks.createIndex({ "priority": 1 });
db.tasks.createIndex({ "dueDate": 1 });
db.tasks.createIndex({ "createdAt": 1 });
db.tasks.createIndex({ "title": "text", "description": "text" });

// Index composé pour les requêtes fréquentes
db.tasks.createIndex({ "projectId": 1, "status": 1 });
db.tasks.createIndex({ "assignedTo": 1, "status": 1 });

// Insérer des données de test
db.tasks.insertMany([
    {
        title: "Tâche Demo 1",
        description: "Première tâche de démonstration",
        projectId: NumberLong(1),
        status: "TODO",
        priority: "MEDIUM",
        assignedTo: "admin",
        createdAt: new Date(),
        updatedAt: new Date()
    },
    {
        title: "Tâche Demo 2",
        description: "Deuxième tâche de démonstration",
        projectId: NumberLong(1),
        status: "IN_PROGRESS",
        priority: "HIGH",
        assignedTo: "user1",
        dueDate: new Date(Date.now() + 7 * 24 * 60 * 60 * 1000), // 7 jours
        createdAt: new Date(),
        updatedAt: new Date()
    }
]);

print("Base de données MongoDB initialisée avec succès!");
print("Collection 'tasks' créée avec validation et index");
print("Données de test insérées");