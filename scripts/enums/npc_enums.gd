extends Node
class_name NPCEnums
## Enums relacionados con NPCs y sus comportamientos

## Roles que puede tomar un NPC
enum Role {
	PATROLMAN,  ## Patrulla un camino
	GUARD,      ## Guarda una posición
	FOLLOWER    ## Sigue al jugador cuando está en rango
}

## Estados posibles de un NPC
enum State {
	PATROL,        ## Patrullando un camino
	FACE,          ## Mirando hacia un objetivo (player)
	ATTACK,
	CHASE_APPLE,   ## Persiguiendo una manzana
	FOLLOW_PLAYER  ## Siguiendo al jugador
}
