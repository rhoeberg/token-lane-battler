/*

next:
- [ ] add more interesting player and enemy tokens
- [ ] proper predesigned enemy waves
- [ ] predesigned player bag
- [ ] shop / draft system
- [ ] bit better ui feedback
- [x] draw system
- [x] enemy wave system
- [x] handle end of game


crazy ideas:
- tokens that are more than 1 tile in size 
- log to show everything happening behind 


draw system:
you have a certain amount of food for the round
whenever you draw a token you consume some food
some tokens consumes more food than 1
if you go minus in food something bad happens
but what?
- you loose
- some penalty 


*/

package game

import "core:fmt"
import "core:math/linalg"
import sa "core:container/small_array"
import rl "vendor:raylib"

_ :: fmt

// GRAPHICS CONFIGURATION
BOARD_COLUMNS :: 6
BOARD_ROWS :: 2
BOARD_PLAYER_TILE_COUNT :: BOARD_COLUMNS * BOARD_ROWS
BOARD_TILE_SIZE :: 100
BOARD_OFFSET_Y :: 50
PLAYER_HAND_Y_START :: 500
PLAYER_HAND_X_START :: 100
PLAYER_ROW_OFFSET_Y :: (BOARD_ROWS * BOARD_TILE_SIZE) + BOARD_OFFSET_Y
BAG_POS_Y :: 600
BAG_POS_X :: 1000
BAG_RADIUS :: 100
END_DRAWING_BUTTON_POS_Y :: 300
END_DRAWING_BUTTON_POS_X :: 1000
END_DRAWING_BUTTON_RADIUS :: 100
MAX_ACTIVE_VFX :: 12

FRONT_ROW :: 0
BACK_ROW :: 1

// GAMEPLAY CONFIGURATION
PLAYER_LIVES :: 5
PLAYER_ROUND_FOOD :: 5
PLAYER_MAX_HAND_SIZE :: 5
PLAYER_MAX_BAG_SIZE :: 30


Rect :: rl.Rectangle
Vec2 :: rl.Vector2
/* Board_Pos :: [2]int */
Board_Pos :: struct {
	x, y: int,
	alliance: Alliance,
}

Alliance :: enum {
	Player,
	Enemy,
}

Board_Token_Type :: enum {
	None,
	Archer,
	Ranger,
	Swordsman,
	Cleaver,
	Healer,
	Rats, // eats food but does nothing
}

Init_State :: struct {}

Attack_Animation :: struct {
	targets: sa.Small_Array(BOARD_PLAYER_TILE_COUNT, Board_Pos),
}

Token_State :: union {
	Init_State,
	Attack_Animation,
}

Token_Attribute_Set :: bit_set[Token_Attributes]
Ability_Target_Set :: bit_set[Ability_Target_Attribute]

Ability_Init_State :: struct{}
Ability_Animation_State :: struct{}
Ability_End_State :: struct{}
Ability_State :: union {
	Ability_Init_State,
	Ability_Animation_State,
	Ability_End_State,
}

Ability :: struct {
	target: Ability_Target_Set,
	effect: Ability_Effect,
	state: Ability_State,
	current_targets: sa.Small_Array(BOARD_PLAYER_TILE_COUNT*2, Board_Pos),
}

Ability_Target_Attribute :: enum {
	Frontline,
	Backline,
	Backline_Priority,
	Frontline_Priority,
	Sweep, // hits targets to the right and behind main target
	/* Pierce, // hits targets behind frontrow targets */
	Self, // targets itself
	Self_Adjacent, // targets token to the left and right of self
	Self_Front, // targets token in front of self
	Self_Behind, // targets token behind self
	// self row
	// self row in front
	// self row behind
	// front row = enemy front row
	// back row = enemy back row
}

Ability_Effect :: enum {
	Damage,
	Heal,
}

Token_Attributes :: enum {
	/* Hit_Frontline, */
	Hit_Backline, // can hit and prioritizes backline
	/* Prio_Backline, // try to hit backline first then hit frontline */
	// Pierce, // hit front and backline
	Sweep,
	Unplayable,
}


TOKEN_MAX_ABILITIES :: 5
Board_Token :: struct {
	type: Board_Token_Type,
	texture_name: Texture_Name,
	alliance: Alliance,
	state: Token_State,
	/* dir: Token_Direction, */
	/* initialized: bool, */
	finished_action: bool,
	attributes: Token_Attribute_Set,

	life: i16,
	value: int, // could value and food cost be combined?
	food_cost: int,

	// TODO (rhoe) should this be an attribute?
	backliner: bool,

	// ability
	abilities: sa.Small_Array(TOKEN_MAX_ABILITIES, Ability),
	current_ability: int,
}

Player_State :: struct {
	current_hand: sa.Small_Array(PLAYER_MAX_HAND_SIZE, Board_Token),
	bag: sa.Small_Array(PLAYER_MAX_BAG_SIZE, Board_Token),

	hovered_token_id: int, 
	hovered_token_active: bool,
	dragged_token_id: int, 
	dragged_token_active: bool,
	dragged_token_offset: Vec2,

	food: int,
}

Start_Round_State :: struct {}
Getting_Tokens_State :: struct {}
Playing_Tokens_State :: struct {}
Doing_Actions_State :: struct {
	initialized: bool,
	start: f64,
	current_board_pos: Board_Pos,
	/* doing_action_action_initialized: bool, */
}
Doing_Enemy_Actions_State :: struct {
	initialized: bool,
	start: f64,
	current_board_pos: Board_Pos,
}
Resolve_Damage_State :: struct {
	done_resolving: bool,
}

Round_End_Result :: enum {
	Player_Won,
	Enemy_Won,
	Draw,
}
Round_End_State :: struct {
	result: Round_End_Result,
}
Player_Won_State :: struct {}
Player_Lost_State :: struct {}

Game_Round_State :: union {
	Start_Round_State,
	Getting_Tokens_State,
	Playing_Tokens_State,
	Doing_Actions_State,
	Doing_Enemy_Actions_State,
	Resolve_Damage_State,
	Round_End_State,
	Player_Won_State,
	Player_Lost_State,
}

Arrow_VFX :: struct {
	start: Vec2,
	target: Vec2,
	t: f32,
}

Sword_VFX :: struct {
}

VFX :: struct {
	start_time: f64,
	done: bool,
	subtype: union {
		Arrow_VFX,
		Sword_VFX,
	},
}

Wave :: struct {
	enemy_rows: [BOARD_COLUMNS][BOARD_ROWS]Board_Token,
}

MAX_WAVES :: 8
MAX_LEVELS :: 20
Level :: struct {
	waves: sa.Small_Array(MAX_WAVES, Wave),
}


Game_Memory :: struct {
	run: bool,
	atlas_texture: rl.Texture,
	enemy_rows: [BOARD_COLUMNS][BOARD_ROWS]Board_Token,
	player_rows: [BOARD_COLUMNS][BOARD_ROWS]Board_Token,
	player: Player_State,
	round_state: Game_Round_State,

	levels: sa.Small_Array(MAX_LEVELS, Level),
	current_level: int,
	current_wave: int,

	/* doing_action_start: f64, */
	/* doing_action_current_board_pos: Board_Pos, */
	/* doing_action_action_initialized: bool, */

	active_vfx: sa.Small_Array(MAX_ACTIVE_VFX, VFX),
	/* archer_arrow_active: bool, */
	/* archer_arrow_target: Vec2, */
	/* archer_arrow_pos: Vec2, */

	player_lives: i32,
	enemy_lives: i32,
}

g: ^Game_Memory

create_board_token :: proc(type: Board_Token_Type, alliance: Alliance) -> Board_Token {
	token: Board_Token
	token.type = type
	token.alliance = alliance
	token.life = 1
	token.value = 1
	token.food_cost = 1
	token.backliner = false
	switch type {
	case .None:
	case .Archer:
		token.texture_name = .Archer
		token.life = 1
		ability: Ability
		ability.effect = .Damage
		ability.target = {.Backline_Priority}
		sa.append(&token.abilities, ability)
		/* token.attributes = {.Hit_Backline} */
		token.backliner = true
	case .Ranger:
		token.texture_name = .Archer
		token.life = 2
		ability: Ability
		ability.effect = .Damage
		ability.target = {.Backline_Priority}
		sa.append(&token.abilities, ability)
		/* token.attributes = {.Hit_Backline} */
		token.backliner = true
	case .Swordsman:
		token.life = 2
		token.value = 2
		token.food_cost = 2
		token.texture_name = .Test_Face
		/* token.attributes = {.Hit_Frontline} */
		ability: Ability
		ability.effect = .Damage
		ability.target = {.Frontline}
		sa.append(&token.abilities, ability)
	case .Cleaver:
		token.life = 1
		token.value = 2
		token.food_cost = 2
		token.texture_name = .Cleaver
		/* token.attributes = {.Sweep} */
		ability: Ability
		ability.effect = .Damage
		ability.target = {.Frontline, .Sweep}
		sa.append(&token.abilities, ability)
	case .Healer:
		
	case .Rats:
		token.life = 1
		token.value = 0
		token.food_cost = 2
		token.texture_name = .Rats
		token.attributes = {.Unplayable}
	}

	return token
}

// get board token from given position
/* get_token_from_board_pos :: proc(pos: Board_Pos, alliance: Alliance) -> (^Board_Token, bool) { */
get_token_from_board_pos :: proc(pos: Board_Pos) -> (^Board_Token, bool) {

	// bounds check 
	if pos.x > BOARD_COLUMNS-1 || pos.y > BOARD_ROWS-1 || pos.x < 0 || pos.y < 0 {
		return nil, false
	}

	// TODO (rhoe) this returns a pointer to a board position,
	// if the token moves the pointer will no longer point to that token
	// but to the now empty board position
	// we should probably store the tokens in a seperate array and use an
	// index offset for the handle
	// this way we can mutate the tokens and they will be correct everywhere
	token: ^Board_Token
	if pos.alliance == .Player {
		token = &g.player_rows[pos.x][pos.y]
	} else {
		token = &g.enemy_rows[pos.x][pos.y]
	}

	return token, true
}

// get the next position given a board position
// moves in reading order (left to right, row by row)
// returns true if next position is within board 
// false otherwise
get_next_board_pos :: proc(pos: Board_Pos) -> (Board_Pos, bool) {
	next_pos := pos
	if next_pos.x < BOARD_COLUMNS-1 {
		next_pos.x += 1
		return next_pos, true
	} else if next_pos.y < BOARD_ROWS-1 {
		next_pos.y += 1
		next_pos.x = 0
		return next_pos, true
	} else {
		return {}, false
	}
}

// get the next position given a board position
// moves in reading order (left to right, row by row)
// no bounds check!
increment_board_position :: proc(pos: Board_Pos) -> Board_Pos {
	next_pos := pos
	if next_pos.x < BOARD_COLUMNS-1 {
		next_pos.x += 1
	} else {
		next_pos.y += 1
		next_pos.x = 0
	} 

	return next_pos
}
decrement_board_position :: proc(pos: Board_Pos) -> Board_Pos {
	next_pos := pos
	if next_pos.x > 0 {
		next_pos.x -= 1
	} else {
		next_pos.y -= 1
		next_pos.x = BOARD_COLUMNS-1
	} 

	return next_pos
}

get_board_pos_screen_pos :: proc(pos: Board_Pos) -> Vec2 {
	result: Vec2
		/* result.x = f32(pos.x * BOARD_TILE_SIZE) */
		/* result.y = f32(pos.y * BOARD_TILE_SIZE) + PLAYER_ROW_OFFSET_Y */
	pos_x := pos.x
	pos_y := pos.alliance == .Enemy ? (BOARD_ROWS-1) - pos.y : pos.y

	result.x = f32(pos_x * BOARD_TILE_SIZE)
	result.y = f32(pos_y * BOARD_TILE_SIZE)
	if pos.alliance == .Player do result.y += PLAYER_ROW_OFFSET_Y

	/* switch alliance { */
	/* case .Player: */
	/* 	result.x = f32(pos.x * BOARD_TILE_SIZE) */
	/* 	result.y = f32(pos.y * BOARD_TILE_SIZE) + PLAYER_ROW_OFFSET_Y */
	/* case .Enemy: */
	/* 	/\* pos_x := (BOARD_COLUMNS-1) - pos.x *\/ */
	/* 	/\* pos_y := (BOARD_ROWS-1) - pos.y *\/ */
	/* 	/\* result.x = f32(pos_x * BOARD_TILE_SIZE) *\/ */
	/* 	/\* result.y = f32(pos_y * BOARD_TILE_SIZE) *\/ */
	/* 	result.x = f32(pos.x * BOARD_TILE_SIZE) */
	/* 	result.y = f32(pos.y * BOARD_TILE_SIZE) */
	/* } */

	return result
}


// searches for next token which is:
// - not type .None
// - matching alliance
// - not finished_action
find_next_token :: proc(start: Board_Pos) -> (Board_Pos, bool) {
	next_pos := start
	for {
		token: ^Board_Token
		token_pos_ok: bool
		if token, token_pos_ok = get_token_from_board_pos(next_pos); !token_pos_ok {
			// token not valid (outside of bounds)
			return {}, false
		}

		// succesfully found token
		if token.type != .None && !token.finished_action {
			return next_pos, true
		}

		next_pos = increment_board_position(next_pos)
	}

}

update :: proc() {
	if rl.IsKeyPressed(.ESCAPE) {
		g.run = false
	}

	switch &state in g.round_state {
	case Start_Round_State:

		fmt.println("STARTING NEW ROUND")

		// reset board
		for x in 0..<BOARD_COLUMNS {
			for y in 0..<BOARD_ROWS {
				if token, token_valid := get_token_from_board_pos({x, y, .Player}); token_valid {
					token.type = .None
				}
			}
		}
		for x in 0..<BOARD_COLUMNS {
			for y in 0..<BOARD_ROWS {
				if token, token_valid := get_token_from_board_pos({x, y, .Enemy}); token_valid {
					token.type = .None
				}
			}
		}

		sa.clear(&g.player.current_hand)

		// setup wave
		level := sa.get_ptr(&g.levels, g.current_level)
		wave := sa.get_ptr(&level.waves, g.current_wave)
		g.enemy_rows = wave.enemy_rows

		g.player.food = PLAYER_ROUND_FOOD
		g.round_state = Getting_Tokens_State{}


	case Getting_Tokens_State:

		// 1. click bag to draw token
		// 2. get token and consume food cost
		// 3. check if we used too much food
		// 4. play token
		// 5. player ends or repeats
		mouse := rl.GetMousePosition()
		if rl.CheckCollisionPointCircle(mouse, {BAG_POS_X, BAG_POS_Y}, BAG_RADIUS) {
			if rl.IsMouseButtonReleased(.LEFT) {

				// check if there is more tokens left
				if sa.len(g.player.bag) <= 0 {
					g.round_state = Player_Lost_State{}
					break
				} 

				fmt.println("PRESSED BAG!")
				rnd := rl.GetRandomValue(0, i32(sa.len(g.player.bag)-1))
				token := sa.get(g.player.bag, int(rnd))
				sa.unordered_remove(&g.player.bag, int(rnd))
				sa.append(&g.player.current_hand, token)
				g.player.food -= token.food_cost
				if g.player.food < 0 {
					g.player_lives -= 1
					/* g.round_state = End_Round_State{} */
					g.round_state = Round_End_State{.Enemy_Won}
					break
				} else if g.player.food == 0 {
					g.round_state = Playing_Tokens_State{}
					break
				}


			}
		}


		
		if rl.CheckCollisionPointCircle(mouse, {END_DRAWING_BUTTON_POS_X, END_DRAWING_BUTTON_POS_Y}, END_DRAWING_BUTTON_RADIUS) {
			if rl.IsMouseButtonReleased(.LEFT) {
				fmt.println("END DRAWING")
				g.round_state = Playing_Tokens_State{}
			}
		}
		
		

	case Playing_Tokens_State:
		g.player.hovered_token_active = false
		mouse := rl.GetMousePosition()
		for i in 0..<PLAYER_MAX_HAND_SIZE {
			rect: Rect
			rect.x = f32(i) * BOARD_TILE_SIZE + PLAYER_HAND_X_START
			rect.y = PLAYER_HAND_Y_START
			rect.width = BOARD_TILE_SIZE
			rect.height = BOARD_TILE_SIZE

			if rl.CheckCollisionPointRec(mouse, rect) {
				g.player.hovered_token_active = true
				g.player.hovered_token_id = i

			}
		}

		if g.player.dragged_token_active {
			// handle dragging
			if rl.IsMouseButtonReleased(.LEFT) {

				// handle dropping token
				// if token is above valid tile on board place it
				// else put token back in hand position (do nothing just set drag not active)
				found_valid_board_position := false
				valid_board_position: Board_Pos
				for x in 0..<BOARD_COLUMNS {
					for y in 0..<BOARD_ROWS {
						dragging_token := sa.get(g.player.current_hand, g.player.dragged_token_id)
						if y == 1 && !dragging_token.backliner {
							continue
						}

						rect: Rect
						rect.x = f32(x) * BOARD_TILE_SIZE
						rect.y = f32(y) * BOARD_TILE_SIZE + PLAYER_ROW_OFFSET_Y
						rect.width = BOARD_TILE_SIZE
						rect.height = BOARD_TILE_SIZE
						if rl.CheckCollisionPointRec(mouse, rect) {
							found_valid_board_position = true
							valid_board_position = {x, y, .Player}
							break
						}
					}
					if found_valid_board_position do break
				}

				if found_valid_board_position {
					// valid board position
					// drop token here
					g.player_rows[valid_board_position.x][valid_board_position.y] = sa.get(g.player.current_hand, g.player.dragged_token_id)
					sa.ordered_remove(&g.player.current_hand, g.player.dragged_token_id)
				}


				g.player.dragged_token_active = false
			}

		} else if g.player.hovered_token_active {
			// handle hovering
			if rl.IsMouseButtonDown(.LEFT) {

				token := sa.get(g.player.current_hand, g.player.hovered_token_id)
				if .Unplayable not_in token.attributes {

					g.player.dragged_token_active = true
					g.player.dragged_token_id = g.player.hovered_token_id
					// setting offset here even though it only counts if we actually start dragging
					token_x := f32(g.player.hovered_token_id) * BOARD_TILE_SIZE + PLAYER_HAND_X_START
					token_y := f32(PLAYER_HAND_Y_START)
					g.player.dragged_token_offset = mouse - {token_x, token_y}
				}
			}
		}

		/////////////////
		// HARDCODED END OF PLAYING TOKENS BUTTON
		if rl.IsKeyPressed(.SPACE) {
			doing_actions: Doing_Actions_State
			doing_actions.initialized = false
			g.round_state = doing_actions
			fmt.println("space pressed")
		}
	case Doing_Actions_State:
		if !state.initialized {
			fmt.println("init player actions")
			for x in 0..<BOARD_COLUMNS {
				for y in 0..<BOARD_ROWS {
					if token, token_valid := get_token_from_board_pos({x, y, .Player}); token_valid {
						token.finished_action = false
						token.state = Init_State{}

						token.current_ability = 0
						for &ability in sa.slice(&token.abilities) {
							ability.state = Ability_Init_State{}
						}
					}
				}
			}

			state.start = rl.GetTime()
			state.current_board_pos = {0, 0, .Player}
			state.initialized = true
		}

		// get token board pos
		token_pos, pos_ok := find_next_token(state.current_board_pos)
		if !pos_ok {

			// TODO (rhoe) DO DAMAGE DIRECTLY ON TURN
			/* for x in 0..<BOARD_COLUMNS { */
			/* 	for y in 0..<BOARD_ROWS { */
			/* 		if token, token_valid := get_token_from_board_pos({x, y}, .Enemy); token_valid { */
			/* 			if token.life <= 0 { */
			/* 				token.type = .None */
			/* 			} */
			/* 		} */
			/* 	} */
			/* } */
			if rl.IsKeyPressed(.SPACE) {

				if round_end, result := check_round_end(); round_end {
					// round finished
					// check if game is over (one player has 0 or less lives)
					fmt.println("ROUND ENDED")

					if game_end, player_won := check_game_end(); game_end {
						if player_won {
							g.round_state = Player_Won_State{}
							break
						} else {
							g.round_state = Player_Lost_State{}
							break
						}
					}


					g.round_state = Round_End_State{result}
						fmt.println("ROUND END STATE")
				} else {
					g.round_state = Doing_Enemy_Actions_State{}
					fmt.println("DOING ENEMY ACTIONS STATE")
				}

			}
			break
		}

		// get token pointer
		current_token, token_ok := get_token_from_board_pos(token_pos)
		if !token_ok || current_token.finished_action {
			state.current_board_pos = increment_board_position(state.current_board_pos)
			break
		}

		// do action
		do_token_action(current_token, token_pos, state.start)


	case Doing_Enemy_Actions_State:
		if !state.initialized {
			fmt.println("init enemy actions")
			for x in 0..<BOARD_COLUMNS {
				for y in 0..<BOARD_ROWS {
					if token, token_valid := get_token_from_board_pos({x, y, .Enemy}); token_valid {
						token.finished_action = false
						token.state = Init_State{}
						token.current_ability = 0
						for &ability in sa.slice(&token.abilities) {
							ability.state = Ability_Init_State{}
						}
					}
				}
			}

			state.start = rl.GetTime()
			state.current_board_pos = {0, 0, .Enemy}
			state.initialized = true
		}

		// get token board pos
		token_pos, pos_ok := find_next_token(state.current_board_pos)
		if !pos_ok {
			if rl.IsKeyPressed(.SPACE) {
				g.round_state = Resolve_Damage_State{false}
				fmt.println("RESOLIVE DAMAGE STATE")
			}
			// TODO (rhoe) DO DAMAGE DIRECTLY ON TURN
			/* for x in 0..<BOARD_COLUMNS { */
			/* 	for y in 0..<BOARD_ROWS { */
			/* 		if token, token_valid := get_token_from_board_pos({x, y}, .Player); token_valid { */
			/* 			if token.life <= 0 { */
			/* 				token.type = .None */
			/* 			} */
			/* 		} */
			/* 	} */
			/* } */

			/* g.round_state = Doing_Actions_State{} */

			break
		}

		// get token pointer
		current_token, token_ok := get_token_from_board_pos(token_pos)
		if !token_ok || current_token.finished_action {
			state.current_board_pos = increment_board_position(state.current_board_pos)
			break
		}

		// do action
		do_token_action(current_token, token_pos, state.start)

	case Resolve_Damage_State:

		if !state.done_resolving {

			/* resolve player token damage */
			for x in 0..<BOARD_COLUMNS {
				for y in 0..<BOARD_ROWS {
					if token, token_valid := get_token_from_board_pos({x, y, .Player}); token_valid && token.type != .None {
						if token.life <= 0 {
							token.type = .None
						}
					}
				}
			}

			// resolve enemy token damage
			for x in 0..<BOARD_COLUMNS {
				for y in 0..<BOARD_ROWS {
					if token, token_valid := get_token_from_board_pos({x, y, .Enemy}); token_valid && token.type != .None {
						if token.life <= 0 {
							fmt.println("ENEMY DIED:", Board_Pos{x, y, .Enemy})
							token.type = .None
						}
					}
				}
			}

			state.done_resolving = true
		}

		if rl.IsKeyPressed(.SPACE) {
			g.round_state = Doing_Actions_State{}
		}


	case Round_End_State:
		if rl.IsKeyPressed(.SPACE) {
			g.round_state = Start_Round_State{}

			// TODO (rhoe) we need to handle when there is no more waves
			g.current_wave += 1
		}
		
	case Player_Lost_State:
	case Player_Won_State:
	}
	

	update_vfx()
}

check_game_end :: proc() -> (game_end:bool, player_won:bool) {
	if g.player_lives <= 0 {
		return true, false
	} else if g.enemy_lives <= 0 {
		return true, true
	}

	return false, false
}

// checks if round ends
// also mutates game state and gives removes life from looser
// returns true if round should end
check_round_end :: proc() -> (bool, Round_End_Result) {
	// check if game ended
	// 1. check if enemy has more tokens
	// 2. check if player has more tokens
	enemy_has_tokens_left := false
	enemy_has_targets := false
	enemy_token_value := 0
	for x in 0..<BOARD_COLUMNS {
		for y in 0..<BOARD_ROWS {
			if token, token_valid := get_token_from_board_pos({x, y, .Enemy}); token_valid {
				if token.type != .None {
					enemy_has_tokens_left = true
					enemy_token_value += token.value
					enemy_has_targets = check_if_token_has_targets(token, {x, y, .Enemy})
				}
			}
		}
	}

	player_has_tokens_left := false
	player_has_targets := false
	player_token_value := 0
	for x in 0..<BOARD_COLUMNS {
		for y in 0..<BOARD_ROWS {
			if token, token_valid := get_token_from_board_pos({x, y, .Player}); token_valid {
				if token.type != .None {
					player_has_tokens_left = true
					player_token_value += token.value
					player_has_targets = check_if_token_has_targets(token, {x, y, .Player})
				}
			}
		}
	}

	if !enemy_has_tokens_left && player_has_tokens_left {
		// player won
		g.enemy_lives -= 1
		return true, .Player_Won
		
	} else if enemy_has_tokens_left && !player_has_tokens_left {
		// enemy won
		g.player_lives -= 1
		return true, .Enemy_Won

	} else if !enemy_has_tokens_left && !player_has_tokens_left {
		// both players lost
		g.player_lives -= 1
		g.enemy_lives -= 1
		return true, .Draw

	} else if enemy_has_tokens_left && player_has_tokens_left {
		if !enemy_has_targets && !player_has_targets {
			// count token value and decide winner
			// player wins if equal value
			if player_token_value >= enemy_token_value {
				g.enemy_lives -= 1
				return true, .Player_Won
			} else {
				g.player_lives -= 1
				return true, .Enemy_Won
			}
			return true, .Draw
		}
	}

	return false, {}
}

/* get_token_counter_pos :: proc(pos: Board_Pos) -> Board_Pos { */
/* 	new_pos: Board_Pos */
/* 	new_pos.x = BOARD_COLUMNS - pos.x - 1 */
/* 	new_pos.y = BOARD_ROWS - pos.y */
/* 	return new_pos */
/* } */

/* get_backline :: proc(x: int, alliance: Alliance) -> Board_Pos { */
/* 	return {x, 1} */
/* 	/\* if alliance == .Player { *\/ */
/* 	/\* 	return {x, 1} *\/ */
/* 	/\* } else { *\/ */
/* 	/\* 	return {x, 0} *\/ */
/* 	/\* } *\/ */
/* } */

/* get_frontline :: proc(x: int, alliance: Alliance) -> Board_Pos { */
/* 	return {x, 0} */
/* 	/\* if alliance == .Player { *\/ */
/* 	/\* 	return {x, 0} *\/ */
/* 	/\* } else { *\/ */
/* 	/\* 	return {x, 1} *\/ */
/* 	/\* } *\/ */
/* } */

get_pos_to_the_side :: proc(pos: Board_Pos, offset: int) -> (Board_Pos, bool) {
	result := Board_Pos{pos.x + offset, pos.y, pos.alliance}
	if result.x < 0 || result.x > BOARD_COLUMNS-1 {
		return {}, false
	}

	return result, true
}

/* // returns the board position of possible targets */
/* get_targets :: proc(token: ^Board_Token, pos: Board_Pos) -> sa.Small_Array(BOARD_PLAYER_TILE_COUNT, Board_Pos) { */
/* 	result: sa.Small_Array(BOARD_PLAYER_TILE_COUNT, Board_Pos) */

/* 	opp_alliance := token.alliance == .Player ? Alliance.Enemy : Alliance.Player */

/* 	/\* if .Hit_Frontline in token.attributes { *\/ */
/* 	/\* 	sa.append(&result, get_frontline(pos.x, opp_alliance)) *\/ */
/* 	/\* 	if .Sweep in token.attributes { *\/ */
/* 	/\* 		// add front plus front-left and front-right token *\/ */
/* 	/\* 		sa.append(&result, get_frontline(pos.x-1, opp_alliance)) *\/ */
/* 	/\* 		sa.append(&result, get_frontline(pos.x+1, opp_alliance)) *\/ */
/* 	/\* 	} *\/ */
/* 	/\* } *\/ */

/* 	main_target_pos := Board_Pos{pos.x, FRONT_ROW, opp_alliance} */

/* 	if .Hit_Backline in token.attributes { */
/* 		if back_token, back_ok := get_token_from_board_pos({pos.x, BACK_ROW, opp_alliance}); back_ok && back_token.type != .None { */
/* 			main_target_pos = {pos.x, BACK_ROW, opp_alliance} */
/* 			fmt.println("TARGETTING BACKLINE: ", main_target_pos) */
/* 		} else { */
/* 			fmt.println("NO BACKLINE TARGET, FRONTLINE: ", main_target_pos) */
/* 		} */
/* 	}  */

/* 	sa.append(&result, main_target_pos) */
/* 	if .Sweep in token.attributes { */
/* 		if left, left_ok := get_pos_to_the_side(main_target_pos, -1); left_ok { */
/* 			sa.append(&result, left) */
/* 		} */
/* 		if right, right_ok := get_pos_to_the_side(main_target_pos, 1); right_ok { */
/* 			sa.append(&result, right) */
/* 		} */
/* 	} */

/* 	return result */
/* } */

check_if_token_has_targets :: proc(token: ^Board_Token, pos: Board_Pos) -> bool {
	for &ability in sa.slice(&token.abilities) {
		targets := get_ability_targets(&ability, pos, token)
		if sa.len(targets) > 0 do return true
	}

	return false
}

// returns the board position of possible targets
get_ability_targets :: proc(ability: ^Ability, pos: Board_Pos, token: ^Board_Token) -> sa.Small_Array(BOARD_PLAYER_TILE_COUNT * 2, Board_Pos) {
	result: sa.Small_Array(BOARD_PLAYER_TILE_COUNT*2, Board_Pos)

	opp_alliance := token.alliance == .Player ? Alliance.Enemy : Alliance.Player

	/* if .Hit_Frontline in token.attributes { */
	/* 	sa.append(&result, get_frontline(pos.x, opp_alliance)) */
	/* 	if .Sweep in token.attributes { */
	/* 		// add front plus front-left and front-right token */
	/* 		sa.append(&result, get_frontline(pos.x-1, opp_alliance)) */
	/* 		sa.append(&result, get_frontline(pos.x+1, opp_alliance)) */
	/* 	} */
	/* } */


	/* main_target_pos := Board_Pos{pos.x, FRONT_ROW, opp_alliance} */
	if .Backline_Priority in ability.target {
		if back_token, back_ok := get_token_from_board_pos({pos.x, BACK_ROW, opp_alliance}); back_ok && back_token.type != .None {
			sa.append(&result, Board_Pos{pos.x, BACK_ROW, opp_alliance})
		} else {
			// no backline try frontline instead
			if front_token, front_ok := get_token_from_board_pos(Board_Pos{pos.x, FRONT_ROW, opp_alliance}); front_ok && front_token.type != .None {
				sa.append(&result, Board_Pos{pos.x, FRONT_ROW, opp_alliance})
			}
		}
	} else if .Frontline_Priority in ability.target {
		if front_token, front_ok := get_token_from_board_pos({pos.x, FRONT_ROW, opp_alliance}); front_ok && front_token.type != .None {
			sa.append(&result, Board_Pos{pos.x, FRONT_ROW, opp_alliance})
		} else {
			// no frontline try backline instead
			if back_token, back_ok := get_token_from_board_pos({pos.x, BACK_ROW, opp_alliance}); back_ok && back_token.type != .None {
				sa.append(&result, Board_Pos{pos.x, BACK_ROW, opp_alliance})
			}
		}
	} else {
		if .Frontline in ability.target {
			// add frontline unit
			if front_token, front_ok := get_token_from_board_pos({pos.x, FRONT_ROW, opp_alliance}); front_ok && front_token.type != .None {
				sa.append(&result, Board_Pos{pos.x, FRONT_ROW, opp_alliance})
			}
		}

		if .Backline in ability.target {
			// add frontline unit
			if back_token, ok := get_token_from_board_pos({pos.x, BACK_ROW, opp_alliance}); ok && back_token.type != .None {
				sa.append(&result, Board_Pos{pos.x, BACK_ROW, opp_alliance})
			}
		}
	}

	/* sa.append(&result, main_target_pos) */
	if .Sweep in ability.target {
		for target_pos in sa.slice(&result) {
			if left, left_ok := get_pos_to_the_side(target_pos, -1); left_ok {
				sa.append(&result, left)
			}
			if right, right_ok := get_pos_to_the_side(target_pos, 1); right_ok {
				sa.append(&result, right)
			}
		}
	}


	if .Self in ability.target {
		sa.append(&result, pos)
	}

	if .Self_Front in ability.target {
		if pos.y != BACK_ROW {
			front_pos := Board_Pos{pos.x, FRONT_ROW, token.alliance}
			if front_token, ok := get_token_from_board_pos(front_pos); ok && front_token.type != .None {
				sa.append(&result, front_pos)
			}
		}
	}

	if .Self_Behind in ability.target {
		if pos.y != FRONT_ROW {
			back_pos := Board_Pos{pos.x, BACK_ROW, token.alliance}
			if back_token, ok := get_token_from_board_pos(back_pos); ok && back_token.type != .None {
				sa.append(&result, back_pos)
			}
		}
	}

	if .Self_Adjacent in ability.target {
		// TODO (rhoe) SHOULD CHECK IF THESE TOKENS ARE NOT NULL
		if left, left_ok := get_pos_to_the_side(pos, -1); left_ok {
			if left_token, ok := get_token_from_board_pos(left); ok && left_token.type != .None {
				sa.append(&result, left)
			}
		}
		if right, right_ok := get_pos_to_the_side(pos, -1); right_ok {
			if right_token, ok := get_token_from_board_pos(right); ok && right_token.type != .None {
				sa.append(&result, right)
			}
		}
	}
	

	return result
}

/////////////////////////////
////// YOU
////// ARE
////// HERE!!!!!!!!!!!!!!
/*
returns true if done
*/
do_token_ability :: proc(ability: ^Ability, pos: Board_Pos, token: ^Board_Token, start_time: f64) -> bool {
	/* fmt.println("DOING TOKEN ABILITY:", ability, token) */
	switch state in ability.state {
	case Ability_Init_State:
		// do targetting etc..
		sa.clear(&ability.current_targets)
		ability.current_targets = get_ability_targets(ability, pos, token)

		for target_pos in sa.slice(&ability.current_targets) {
			fmt.println("found target:", target_pos)

			// TODO (rhoe) hardcoding the arrow anim for all units
			// ---
			// later we probably want to be able to configure the animation for each token
			// with a more generalized animation system
			arrow: Arrow_VFX
			arrow.t = 0
			arrow.start = get_board_pos_screen_pos(pos) + ({BOARD_TILE_SIZE, BOARD_TILE_SIZE}/2)
			arrow.target = get_board_pos_screen_pos(target_pos) + {BOARD_TILE_SIZE, BOARD_TILE_SIZE}/2
			vfx: VFX
			vfx.done = false
			vfx.start_time = rl.GetTime()
			vfx.subtype = arrow
			sa.append(&g.active_vfx, vfx)
		}

		ability.state = Ability_Animation_State{}

	case Ability_Animation_State:
		// wait for animation to finish
		// TODO (rhoe) currently just looks for any VFX to be done
		if sa.len(g.active_vfx) <= 0 {
			fmt.println("FINISHED ABILITIES")
			ability.state = Ability_End_State{}
		}

	case Ability_End_State:
		// deal damage etc..
		for target_pos in sa.slice(&ability.current_targets) {
			if target_token, target_token_ok := get_token_from_board_pos(target_pos); target_token_ok && target_token.type != .None {
				target_token.life -= 1
			}
			
		}
		return true
	}


	return false
}

// returns returns false if token is done
// TODO (rhoe) probably a bit of a confusion return var
do_token_action :: proc(token: ^Board_Token, pos: Board_Pos, start_time: f64) {

	if token.finished_action do return

	if sa.len(token.abilities) == 0 {
		token.finished_action = true
		return 
	}

	if do_token_ability(sa.get_ptr(&token.abilities, token.current_ability), pos, token, start_time) {
		token.current_ability += 1
		if token.current_ability >= sa.len(token.abilities)-1 {
			token.finished_action = true
		}
	}


	/* if token.finished_action do return */

	/* #partial switch &variant in token.state { */
	/* case Init_State: */
	/* 	// handle token init targetting */

	/* 	attack_anim_state: Attack_Animation */
	/* 	attack_anim_state.targets = get_targets(token, pos) */

	/* 	opp_alliance := token.alliance == .Player ? Alliance.Enemy : Alliance.Player */
	/* 	sa.clear(&g.active_vfx) */
	/* 	for target_pos in sa.slice(&attack_anim_state.targets) { */
	/* 		fmt.println("found target:", target_pos) */

	/* 		// TODO (rhoe) hardcoding the arrow anim for all units */
	/* 		// --- */
	/* 		// later we probably want to be able to configure the animation for each token */
	/* 		// with a more generalized animation system */
	/* 		arrow: Arrow_VFX */
	/* 		arrow.t = 0 */
	/* 		arrow.start = get_board_pos_screen_pos(pos, token.alliance) + ({BOARD_TILE_SIZE, BOARD_TILE_SIZE}/2) */
	/* 		arrow.target = get_board_pos_screen_pos(target_pos, opp_alliance) + {BOARD_TILE_SIZE, BOARD_TILE_SIZE}/2 */
	/* 		vfx: VFX */
	/* 		vfx.done = false */
	/* 		vfx.start_time = rl.GetTime() */
	/* 		vfx.subtype = arrow */
	/* 		sa.append(&g.active_vfx, vfx) */
	/* 	} */

	/* 	token.state = attack_anim_state */

	/* case Attack_Animation: */
	/* 	if sa.len(g.active_vfx) <= 0 { */
	/* 		token.finished_action = true */

	/* 		for target_pos in sa.slice(&variant.targets) { */


	/* 			// TODO (rhoe) Hardcoded damage system, needs to be extended to a tagging system */
	/* 			if target_token, target_token_ok := get_token_from_board_pos(target_pos); target_token_ok { */
	/* 				target_token.life -= 1 */
	/* 				/\* target_token.type = .None *\/ */
	/* 			} */
	/* 		} */

	/* 		token.finished_action = true */
	/* 	} */

	/* } */
}

update_vfx :: proc() {
	for &fx in sa.slice(&g.active_vfx) {
		switch &sub in fx.subtype {
		case Arrow_VFX:
			ARROW_SPEED :: 3.0
			sub.t += ARROW_SPEED * rl.GetFrameTime()
			if sub.t > 1.0 {
				fx.done = true
				break
			}
		case Sword_VFX:
		}
	}


	// remove vfx
	#reverse for fx, i in sa.slice(&g.active_vfx) {
		if fx.done do sa.ordered_remove(&g.active_vfx, i)
	}
}


draw_vfx :: proc() {
	for fx in sa.slice(&g.active_vfx) {
		switch sub in fx.subtype {
		case Arrow_VFX:
			pos := linalg.lerp(sub.start, sub.target, sub.t)
			rl.DrawCircle(i32(pos.x), i32(pos.y), 15, rl.RED)

		case Sword_VFX:
		}
	}
}


draw :: proc() {
	rl.BeginDrawing()
	rl.ClearBackground(rl.BLUE)


	////////////
	// DRAW BOARD OUTLINE
	for x in 0..<BOARD_COLUMNS {
		for y in 0..<BOARD_ROWS*2 {
			x_pos := x * BOARD_TILE_SIZE
			/* y_pos := y * BOARD_TILE_SIZE + PLAYER_ROW_OFFSET_Y */
			y_pos := (y * BOARD_TILE_SIZE) + BOARD_OFFSET_Y
			rl.DrawRectangleLines(i32(x_pos), i32(y_pos), BOARD_TILE_SIZE, BOARD_TILE_SIZE, rl.BLACK)
		}
	}

	////////////
	// DRAW PLAYER BOARD TOKENS
	for x in 0..<BOARD_COLUMNS {
		for y in 0..<BOARD_ROWS {
			board_token := g.player_rows[x][y]

			rect: Rect
			rect.x = f32(x) * BOARD_TILE_SIZE
			rect.y = f32(y) * BOARD_TILE_SIZE + f32(PLAYER_ROW_OFFSET_Y)
			rect.width = BOARD_TILE_SIZE
			rect.height = BOARD_TILE_SIZE
			if board_token.type != .None {
				rl.DrawTexturePro(g.atlas_texture, atlas_textures[board_token.texture_name].rect, rect, {}, 0, rl.WHITE)
				rl.DrawText(rl.TextFormat("%d", board_token.life), i32(rect.x), i32(rect.y+24), 24, rl.RED)
			}


			/* rl.DrawText(rl.TextFormat("(%d, %d)", x, y), i32(rect.x), i32(rect.y), 24, rl.GREEN) */
		}
	}

	////////////
	// DRAW ENEMY BOARD TOKENS
	for x in 0..<BOARD_COLUMNS {
		for y in 0..<BOARD_ROWS {

			// TODO (rhoe) enemy tokens are placed reverse to player tokens so
			//             pos {0, 0} is front right
			
			/* x_pos := (BOARD_COLUMNS-1) - x */
			y_pos := (BOARD_ROWS-1) - y
			x_pos := x
			/* y_pos := y */
			board_token := g.enemy_rows[x_pos][y_pos]
			rect: Rect
			rect.x = f32(x) * BOARD_TILE_SIZE
			rect.y = (f32(y) * BOARD_TILE_SIZE) + BOARD_OFFSET_Y
			rect.width = BOARD_TILE_SIZE
			rect.height = BOARD_TILE_SIZE
			if board_token.type != .None {
				rl.DrawTexturePro(g.atlas_texture, atlas_textures[board_token.texture_name].rect, rect, {}, 0, rl.WHITE)
				rl.DrawText(rl.TextFormat("%d", board_token.life), i32(rect.x), i32(rect.y+24), 24, rl.RED)
			}

			/* rl.DrawText(rl.TextFormat("(%d, %d)", x_pos, y_pos), i32(rect.x), i32(rect.y), 14, rl.GREEN) */

		}
	}



	///////////
	// DRAW PLAYER HAND
	for i in 0..<sa.len(g.player.current_hand) {
		board_token := sa.get(g.player.current_hand, i)
		if g.player.dragged_token_active && g.player.dragged_token_id == i {
			mouse := rl.GetMousePosition()
			rect: Rect
			rect.x = mouse.x - g.player.dragged_token_offset.x
			rect.y = mouse.y - g.player.dragged_token_offset.y
			rect.width = BOARD_TILE_SIZE
			rect.height = BOARD_TILE_SIZE
			rl.DrawTexturePro(g.atlas_texture, atlas_textures[board_token.texture_name].rect, rect, {}, 0, rl.WHITE)

		} else {
			rect: Rect
			rect.x = f32(i) * BOARD_TILE_SIZE + PLAYER_HAND_X_START
			rect.y = PLAYER_HAND_Y_START
			rect.width = BOARD_TILE_SIZE
			rect.height = BOARD_TILE_SIZE
			rl.DrawTexturePro(g.atlas_texture, atlas_textures[board_token.texture_name].rect, rect, {}, 0, rl.WHITE)
			if g.player.hovered_token_active && g.player.hovered_token_id == i {
				rl.DrawRectangleRec(rect, rl.Fade(rl.PURPLE, 0.5))
			}
		}
	}


	//////////
	// DRAW PLAYER BAG
	rl.DrawCircle(BAG_POS_X, BAG_POS_Y, BAG_RADIUS, rl.BROWN)
	rl.DrawText(rl.TextFormat("%d", sa.len(g.player.bag)), BAG_POS_X, BAG_POS_Y, 20, rl.WHITE)
	rl.DrawCircle(END_DRAWING_BUTTON_POS_X, END_DRAWING_BUTTON_POS_Y, END_DRAWING_BUTTON_RADIUS, rl.GRAY)

	//////////
	// DRAW UI
	rl.DrawText(rl.TextFormat("enemy lives:%d", g.enemy_lives), 0, 0, 20, rl.RED)
	rl.DrawText(rl.TextFormat("player lives:%d", g.player_lives), 400, 0, 20, rl.RED)
	rl.DrawText(rl.TextFormat("FOOD:%d", g.player.food), 1000, 100, 20, rl.GREEN)

	#partial switch state in g.round_state {
	case Round_End_State:
		switch state.result {
		case .Player_Won:
			rl.DrawText("ROUND WON!", 100, 200, 40, rl.GREEN)
		case .Enemy_Won:
			rl.DrawText("ROUND LOST!", 100, 200, 40, rl.RED)
		case .Draw:
			rl.DrawText("DRAW!", 100, 200, 40, rl.RED)
		}
	case Player_Won_State:
		rl.DrawText("YOU WON", 100, 200, 40, rl.GREEN)
	case Player_Lost_State:
		rl.DrawText("YOU LOST", 100, 200, 40, rl.GREEN)
	}

	draw_vfx()

	rl.EndDrawing()
}

@(export)
game_update :: proc() {
	update()
	draw()

	// Everything on tracking allocator is valid until end-of-frame.
	free_all(context.temp_allocator)
}

@(export)
game_init_window :: proc() {
	rl.SetConfigFlags({.WINDOW_RESIZABLE, .VSYNC_HINT})
	rl.InitWindow(1280, 720, "tokens")
	rl.SetWindowPosition(200, 200)
	rl.SetTargetFPS(500)
	rl.SetExitKey(nil)
}

@(export)
game_init :: proc() {
	g = new(Game_Memory)

	// set to run
	g.run = true

	// compile atlas
	atlas_data := #load("../atlas.png")
	fmt.println("IMAGE SIZE", len(atlas_data))
	atlas_image := rl.LoadImageFromMemory(".png", raw_data(atlas_data[:]), i32(len(atlas_data)))
	g.atlas_texture = rl.LoadTextureFromImage(atlas_image)

	g.round_state = Start_Round_State{}

	// setup game board
	for x in 0..<BOARD_COLUMNS {
		for y in 0..<BOARD_ROWS {
			g.player_rows[x][y] = Board_Token{type=.None}
			g.enemy_rows[x][y] = Board_Token{type=.None}
		}
	}

	for _ in 0..<PLAYER_MAX_BAG_SIZE {
		token_type := Board_Token_Type(rl.GetRandomValue(1, len(Board_Token_Type)-1))
		sa.append(&g.player.bag, create_board_token(token_type, .Player))
	}

	sa.clear(&g.player.current_hand)
	/* for _ in 0..<PLAYER_MAX_HAND_SIZE { */
	/* 	token_type := Board_Token_Type(rl.GetRandomValue(1, len(Board_Token_Type)-1)) */
	/* 	sa.append(&g.player.current_hand, create_board_token(token_type, .Player)) */
	/* } */

	// setup enemies
	/* for x in 0..<BOARD_COLUMNS { */
	/* 	for y in 0..<BOARD_ROWS { */
	/* 		token := create_board_token(.Archer, .Enemy) */
	/* 		/\* token.dir = .Down *\/ */
	/* 		g.enemy_rows[x][y] = token */
	/* 	} */
	/* } */

	/* token := create_board_token(.Archer, .Enemy) */
	/* g.enemy_rows[0][0] = token */

	g.player_lives = PLAYER_LIVES
	g.enemy_lives = PLAYER_LIVES


	////////////////
	// SETUP WAVES
	/* level: Level */
	sa.append(&g.levels, Level{})
	level := sa.get_ptr(&g.levels, 0)

	for _ in 0..<MAX_WAVES {
		wave: Wave

		wave_amount := rl.GetRandomValue(3, 6)
		fmt.println("WAVE AMOUNT", wave_amount)
		for _ in 0..<wave_amount {
			token_type := Board_Token_Type(rl.GetRandomValue(1, len(Board_Token_Type)-1))
			token := create_board_token(token_type, .Enemy)

			for {
				y := int(rl.GetRandomValue(0, 1))
				x := int(rl.GetRandomValue(0, BOARD_COLUMNS-1))
				if y== 1 && !token.backliner do continue

				
				wave.enemy_rows[x][y] = token
				break
			}
		}

		/* for _ in 0..<4 { */
		/* 	y := int(rl.GetRandomValue(0, 1)) */
		/* 	x := int(rl.GetRandomValue(0, BOARD_COLUMNS-1)) */
		/* 	token := create_board_token(.Archer, .Enemy) */
		/* 	wave.enemy_rows[x][y] = token */
		/* } */
		sa.append(&level.waves, wave)
	}
	/* sa.append(&g.levels, level) */
	g.current_level = 0
	g.current_wave = 0


	game_hot_reloaded(g)
}

@(export)
game_should_run :: proc() -> bool {
	when ODIN_OS != .JS {
		// Never run this proc in browser. It contains a 16 ms sleep on web!
		if rl.WindowShouldClose() {
			return false
		}
	}

	return g.run
}

@(export)
game_shutdown :: proc() {
	free(g)
}

@(export)
game_shutdown_window :: proc() {
	rl.CloseWindow()
}

@(export)
game_memory :: proc() -> rawptr {
	return g
}

@(export)
game_memory_size :: proc() -> int {
	return size_of(Game_Memory)
}

@(export)
game_hot_reloaded :: proc(mem: rawptr) {
	g = (^Game_Memory)(mem)

	// Here you can also set your own global variables. A good idea is to make
	// your global variables into pointers that point to something inside `g`.
}

@(export)
game_force_reload :: proc() -> bool {
	return rl.IsKeyPressed(.F5)
}

@(export)
game_force_restart :: proc() -> bool {
	return rl.IsKeyPressed(.F6)
}

// In a web build, this is called when browser changes size. Remove the
// `rl.SetWindowSize` call if you don't want a resizable game.
game_parent_window_size_changed :: proc(w, h: int) {
	rl.SetWindowSize(i32(w), i32(h))
}
