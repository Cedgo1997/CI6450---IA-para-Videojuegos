extends Node
class_name EnemyEnums
## Enums relacionados con enemigos y algoritmos de steering

## Algoritmos de steering cinemáticos (sin aceleración)
enum KinematicAlgorithm {
	SEEK,    ## Buscar objetivo directamente
	ARRIVE,  ## Llegar al objetivo desacelerando
	WANDER   ## Vagar sin rumbo fijo
}

## Algoritmos de steering dinámicos (con aceleración)
enum DynamicAlgorithm {
	STEERING_SEEK,              ## Seek con aceleración
	STEERING_FLEE,              ## Huir del objetivo
	STEERING_ARRIVE,            ## Arrive con aceleración
	ALIGN,                      ## Alinear rotación con objetivo
	VELOCITY_MATCH,             ## Igualar velocidad del objetivo
	ALIGN_AND_VELOCITY_MATCH,   ## Combinación de align y velocity match
	PURSUE,                     ## Perseguir prediciendo movimiento
	EVADE,                      ## Evadir prediciendo movimiento
	FACE,                       ## Mirar hacia el objetivo
	WANDER_DYNAMIC              ## Vagar con comportamiento dinámico
}

## Algoritmos de steering avanzados para Enemy 3
enum AdvancedSteeringAlgorithm {
	ALIGN,
	VELOCITY_MATCH,
	ALIGN_AND_VELOCITY_MATCH,
	PURSUE,
	EVADE,
	FACE,
	WANDER
}

## Algoritmos simples para Enemy 4
enum SimpleSteeringAlgorithm {
	WANDER,
	OBSTACLE_AVOIDANCE
}

