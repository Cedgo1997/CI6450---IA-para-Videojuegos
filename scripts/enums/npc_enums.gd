extends Node
class_name NPCEnums
## Enums relacionados con NPCs y sus comportamientos

## Roles que puede tomar un NPC
enum Role {
	PATROLMAN,  ## Patrulla un camino
	GUARD       ## Guarda una posición
}

## Estados posibles de un NPC
enum State {
	PATROL,      ## Patrullando un camino
	FACE,        ## Mirando hacia un objetivo (player)
	ATTACK,
	CHASE_APPLE  ## Persiguiendo una manzana
}
