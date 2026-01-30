/*

next:
- draw system
- enemy wave system
- handle end of game
- log to show everything happening behind 


crazy ideas:
- tokens that are more than 1 tile in size 


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

BOARD_COLUMNS :: 6
BOARD_ROWS :: 2
BOARD_PLAYER_TILE_COUNT :: BOARD_COLUMNS * BOARD_ROWS
BOARD_TILE_SIZE :: 100
BOARD_OFFSET_Y :: 50
PLAYER_HAND_Y_START :: 500
PLAYER_HAND_X_START :: 100
PLAYER_MAX_HAND_SIZE :: 5

PLAYER_ROW_OFFSET_Y :: (BOARD_ROWS * BOARD_TILE_SIZE) + BOARD_OFFSET_Y

Rect :: rl.Rectangle
Vec2 :: rl.Vector2
Board_Pos :: [2]int

Alliance :: enum {
	Player,
	Enemy,
}

Board_Token_Type :: enum {
	None,
	Archer,
	Ranger,
	Swordsman,
}

//////////////////
// SWORDSMAN STATE

Swordsman_State :: struct {
}


//////////////////
// ARCHER STATE

Archer_Shooting :: struct {
	// handle shooting stuff
	target: Board_Pos,
}

Archer_Moving :: struct {
	target: Board_Pos,
}

Swordsman_Moving :: struct {
}

Init_State :: struct {}

Attack_Animation :: struct {
	targets: sa.Small_Array(BOARD_PLAYER_TILE_COUNT, Board_Pos),
}

Token_State :: union {
	Init_State,
	Attack_Animation,
	/* Archer_Shooting, */
	/* Archer_Moving, */
	/* Swordsman_Moving, */
}

/* Token_Direction :: enum { */
/* 	Up, */
/* 	Down, */
/* } */

Token_Attributes :: enum {
	Hit_Frontline,
	Hit_Backline,
	/* Prio_Backline, // try to hit backline first then hit frontline */
	// Pierce, // hit front and backline
	Sweep,
}

Token_Attribute_Set :: bit_set[Token_Attributes]

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
	value: int,
}

Player_State :: struct {
	current_hand: sa.Small_Array(PLAYER_MAX_HAND_SIZE, Board_Token),

	hovered_token_id: int, 
	hovered_token_active: bool,
	dragged_token_id: int, 
	dragged_token_active: bool,
	dragged_token_offset: Vec2,
}

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
Resolve_Damage_State :: struct {}

Game_Round_State :: union {
	Getting_Tokens_State,
	Playing_Tokens_State,
	Doing_Actions_State,
	Doing_Enemy_Actions_State,
	Resolve_Damage_State,
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

MAX_ACTIVE_VFX :: 12
Game_Memory :: struct {
	run: bool,
	atlas_texture: rl.Texture,
	enemy_rows: [BOARD_COLUMNS][BOARD_ROWS]Board_Token,
	player_rows: [BOARD_COLUMNS][BOARD_ROWS]Board_Token,
	player: Player_State,
	round_state: Game_Round_State,

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
	switch type {
	case .None:
	case .Archer:
		token.texture_name = .Archer
		token.life = 1
		/* token.attributes = {.Hit_Backline, .Hit_Frontline, .Sweep} */
		token.attributes = {.Hit_Backline}
		/* token.state = archer_state */
	case .Ranger:
		token.texture_name = .Archer
		token.life = 2
		/* token.attributes = {.Hit_Backline, .Hit_Frontline, .Sweep} */
		token.attributes = {.Hit_Backline}
		/* token.state = archer_state */
	case .Swordsman:
		token.life = 2
		token.value = 2
		token.texture_name = .Test_Face
		token.attributes = {.Hit_Frontline}
	}

	return token
}

// get board token from given position
get_token_from_board_pos :: proc(pos: Board_Pos, alliance: Alliance) -> (^Board_Token, bool) {

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
	if alliance == .Player {
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

get_board_pos_screen_pos :: proc(pos: Board_Pos, alliance: Alliance) -> Vec2 {
	result: Vec2
		/* result.x = f32(pos.x * BOARD_TILE_SIZE) */
		/* result.y = f32(pos.y * BOARD_TILE_SIZE) + PLAYER_ROW_OFFSET_Y */

	switch alliance {
	case .Player:
		result.x = f32(pos.x * BOARD_TILE_SIZE)
		result.y = f32(pos.y * BOARD_TILE_SIZE) + PLAYER_ROW_OFFSET_Y
	case .Enemy:
		/* pos_x := (BOARD_COLUMNS-1) - pos.x */
		/* pos_y := (BOARD_ROWS-1) - pos.y */
		/* result.x = f32(pos_x * BOARD_TILE_SIZE) */
		/* result.y = f32(pos_y * BOARD_TILE_SIZE) */
		result.x = f32(pos.x * BOARD_TILE_SIZE)
		result.y = f32(pos.y * BOARD_TILE_SIZE)
	}

	return result
}


// searches for next token which is:
// - not type .None
// - matching alliance
// - not finished_action
find_next_token :: proc(start: Board_Pos, alliance: Alliance) -> (Board_Pos, bool) {
	next_pos := start
	for {
		token: ^Board_Token
		token_pos_ok: bool
		if token, token_pos_ok = get_token_from_board_pos(next_pos, alliance); !token_pos_ok {
			// token not valid (outside of bounds)
			return {}, false
		}

		// succesfully found token
		if token.type != .None && token.alliance == alliance && !token.finished_action {
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
	case Getting_Tokens_State:
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
						rect: Rect
						rect.x = f32(x) * BOARD_TILE_SIZE
						rect.y = f32(y) * BOARD_TILE_SIZE + PLAYER_ROW_OFFSET_Y
						rect.width = BOARD_TILE_SIZE
						rect.height = BOARD_TILE_SIZE
						if rl.CheckCollisionPointRec(mouse, rect) {
							found_valid_board_position = true
							valid_board_position = {x, y}
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
				g.player.dragged_token_active = true
				g.player.dragged_token_id = g.player.hovered_token_id
				// setting offset here even though it only counts if we actually start dragging
				token_x := f32(g.player.hovered_token_id) * BOARD_TILE_SIZE + PLAYER_HAND_X_START
				token_y := f32(PLAYER_HAND_Y_START)
				g.player.dragged_token_offset = mouse - {token_x, token_y}
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
					if token, token_valid := get_token_from_board_pos({x, y}, .Player); token_valid {
						token.finished_action = false
						token.state = Init_State{}
					}
				}
			}

			state.start = rl.GetTime()
			state.current_board_pos = {0, 0}
			state.initialized = true
		}

		// get token board pos
		token_pos, pos_ok := find_next_token(state.current_board_pos, .Player)
		if !pos_ok {
			


			// TODO (rhoe) DO DAMAGE DIRECTLY ON TURN
			for x in 0..<BOARD_COLUMNS {
				for y in 0..<BOARD_ROWS {
					if token, token_valid := get_token_from_board_pos({x, y}, .Enemy); token_valid {
						if token.life <= 0 {
							token.type = .None
						}
					}
				}
			}

			if check_round_end() {
				// round finished
				// check if game is over (one player has 0 or less lives)
				fmt.println("ROUND ENDED")
				g.round_state = Playing_Tokens_State{}
			} else {
				g.round_state = Doing_Enemy_Actions_State{}
			}

			break
		}

		// get token pointer
		current_token, token_ok := get_token_from_board_pos(token_pos, .Player)
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
					if token, token_valid := get_token_from_board_pos({x, y}, .Enemy); token_valid {
						token.finished_action = false
						token.state = Init_State{}
					}
				}
			}

			state.start = rl.GetTime()
			state.current_board_pos = {0, 0}
			state.initialized = true
		}

		// get token board pos
		token_pos, pos_ok := find_next_token(state.current_board_pos, .Enemy)
		if !pos_ok {
			/* g.round_state = Resolve_Damage_State{} */
			// TODO (rhoe) DO DAMAGE DIRECTLY ON TURN
			for x in 0..<BOARD_COLUMNS {
				for y in 0..<BOARD_ROWS {
					if token, token_valid := get_token_from_board_pos({x, y}, .Player); token_valid {
						if token.life <= 0 {
							token.type = .None
						}
					}
				}
			}

			g.round_state = Doing_Actions_State{}

			break
		}

		// get token pointer
		current_token, token_ok := get_token_from_board_pos(token_pos, .Enemy)
		if !token_ok || current_token.finished_action {
			state.current_board_pos = increment_board_position(state.current_board_pos)
			break
		}

		// do action
		do_token_action(current_token, token_pos, state.start)

	case Resolve_Damage_State:
		// resolve player token damage
		/* for x in 0..<BOARD_COLUMNS { */
		/* 	for y in 0..<BOARD_ROWS { */
		/* 		if token, token_valid := get_token_from_board_pos({x, y}, .Player); token_valid { */
		/* 			if token.life <= 0 { */
		/* 				token.type = .None */
		/* 			} */
		/* 		} */
		/* 	} */
		/* } */

		/* // resolve enemy token damage */
		/* for x in 0..<BOARD_COLUMNS { */
		/* 	for y in 0..<BOARD_ROWS { */
		/* 		if token, token_valid := get_token_from_board_pos({x, y}, .Player); token_valid { */
		/* 			if token.life <= 0 { */
		/* 				token.type = .None */
		/* 			} */
		/* 		} */
		/* 	} */
		/* } */


	}
	

	update_vfx()
}


// checks if round ends
// also mutates game state and gives removes life from looser
// returns true if round should end
check_round_end :: proc() -> bool {
	// check if game ended
	// 1. check if enemy has more tokens
	// 2. check if player has more tokens
	enemy_has_tokens_left := false
	enemy_has_targets := false
	enemy_token_value := 0
	for x in 0..<BOARD_COLUMNS {
		for y in 0..<BOARD_ROWS {
			if token, token_valid := get_token_from_board_pos({x, y}, .Enemy); token_valid {
				if token.type != .None {
					enemy_has_tokens_left = true
					enemy_token_value += token.value
					targets := get_targets(token, {x, y})
					for target_pos in sa.slice(&targets) {
						if target, ok := get_token_from_board_pos(target_pos, .Player); ok {
							if target.type != .None {
								enemy_has_targets = true
								break
							}
						}
					}
				}
			}
		}
	}

	player_has_tokens_left := false
	player_has_targets := false
	player_token_value := 0
	for x in 0..<BOARD_COLUMNS {
		for y in 0..<BOARD_ROWS {
			if token, token_valid := get_token_from_board_pos({x, y}, .Player); token_valid {
				if token.type != .None {
					player_has_tokens_left = true
					player_token_value += token.value
					targets := get_targets(token, {x, y})
					for target_pos in sa.slice(&targets) {
						if target, ok := get_token_from_board_pos(target_pos, .Enemy); ok {
							if target.type != .None {
								player_has_targets = true
								break
							}
						}
					}
				}
			}
		}
	}

	if !enemy_has_tokens_left && player_has_tokens_left {
		// player won
		g.enemy_lives -= 1
		return true
		
	} else if enemy_has_tokens_left && !player_has_tokens_left {
		// enemy won
		g.player_lives -= 1
		return true

	} else if !enemy_has_tokens_left && !player_has_tokens_left {
		// both players lost
		g.player_lives -= 1
		g.enemy_lives -= 1
		return true

	} else if enemy_has_tokens_left && player_has_tokens_left {
		if !enemy_has_targets && !player_has_targets {
			// count token value and decide winner
			// player wins if equal value
			if player_token_value >= enemy_token_value {
				g.enemy_lives -= 1
			} else {
				g.player_lives -= 1
			}

			return true
		}
	}

	return false
}

/* get_token_counter_pos :: proc(pos: Board_Pos) -> Board_Pos { */
/* 	new_pos: Board_Pos */
/* 	new_pos.x = BOARD_COLUMNS - pos.x - 1 */
/* 	new_pos.y = BOARD_ROWS - pos.y */
/* 	return new_pos */
/* } */

get_backline :: proc(x: int, alliance: Alliance) -> Board_Pos {
	if alliance == .Player {
		return {x, 1}
	} else {
		return {x, 0}
	}
}

get_frontline :: proc(x: int, alliance: Alliance) -> Board_Pos {
	if alliance == .Player {
		return {x, 0}
	} else {
		return {x, 1}
	}
}

// returns the board position of possible targets
get_targets :: proc(token: ^Board_Token, pos: Board_Pos) -> sa.Small_Array(BOARD_PLAYER_TILE_COUNT, Board_Pos) {
	result: sa.Small_Array(BOARD_PLAYER_TILE_COUNT, Board_Pos)

	opp_alliance := token.alliance == .Player ? Alliance.Enemy : Alliance.Player

	if .Hit_Frontline in token.attributes {
		sa.append(&result, get_frontline(pos.x, opp_alliance))
		if .Sweep in token.attributes {
			// add front plus front-left and front-right token
			sa.append(&result, get_frontline(pos.x-1, opp_alliance))
			sa.append(&result, get_frontline(pos.x+1, opp_alliance))
		}
	}

	if .Hit_Backline in token.attributes {
		sa.append(&result, get_backline(pos.x, opp_alliance))
		if .Sweep in token.attributes {
			sa.append(&result, get_backline(pos.x-1, opp_alliance))
			sa.append(&result, get_backline(pos.x+1, opp_alliance))
		}
	}


	return result
}

// returns returns false if token is done
// TODO (rhoe) probably a bit of a confusion return var
do_token_action :: proc(token: ^Board_Token, pos: Board_Pos, start_time: f64) {

	if token.finished_action do return

	#partial switch &variant in token.state {
	case Init_State:
		// handle token init targetting

		attack_anim_state: Attack_Animation
		attack_anim_state.targets = get_targets(token, pos)

		opp_alliance := token.alliance == .Player ? Alliance.Enemy : Alliance.Player
		sa.clear(&g.active_vfx)
		for target_pos in sa.slice(&attack_anim_state.targets) {
			fmt.println("found target:", target_pos)

			// TODO (rhoe) hardcoding the arrow anim for all units
			// ---
			// later we probably want to be able to configure the animation for each token
			// with a more generalized animation system
			arrow: Arrow_VFX
			arrow.t = 0
			arrow.start = get_board_pos_screen_pos(pos, token.alliance) + {BOARD_TILE_SIZE, BOARD_TILE_SIZE}/2
			arrow.target = get_board_pos_screen_pos(target_pos, opp_alliance) + {BOARD_TILE_SIZE, BOARD_TILE_SIZE}/2
			vfx: VFX
			vfx.done = false
			vfx.start_time = rl.GetTime()
			vfx.subtype = arrow
			sa.append(&g.active_vfx, vfx)
		}

		token.state = attack_anim_state

	case Attack_Animation:
		if sa.len(g.active_vfx) <= 0 {
			token.finished_action = true

			
			
			opposite_alliance := token.alliance == .Player ? Alliance.Enemy : Alliance.Player
			for target_pos in sa.slice(&variant.targets) {


				// TODO (rhoe) Hardcoded damage system, needs to be extended to a tagging system
				if target_token, target_token_ok := get_token_from_board_pos(target_pos, opposite_alliance); target_token_ok {
					target_token.life -= 1
					/* target_token.type = .None */
				}
			}

			token.finished_action = true
		}

	}


	/*
	#partial switch token.type {
	case .Archer:
		#partial switch variant in token.state {
		case Init_State:

			// handle initialization of archer action here
			/* token.initialized = true */
			found_target := false
			/* target_pos: Board_Pos */
			target_token: ^Board_Token

			opposite_alliance := token.alliance == .Player ? Alliance.Enemy : Alliance.Player

			target_pos := Board_Pos{pos.x, 1}
			target_token, found_target = get_token_from_board_pos(target_pos, opposite_alliance)
			if !found_target || target_token.type == .None {
				target_pos = Board_Pos{pos.x, 0}
				target_token, found_target = get_token_from_board_pos(target_pos, opposite_alliance)
				// TODO (rhoe) messy
				if target_token.type == .None {
					found_target = false
				}
			}


			if found_target {
				fmt.println("found target:", target_pos)
				sa.clear(&g.active_vfx)
				arrow: Arrow_VFX
				arrow.t = 0
				arrow.start = get_board_pos_screen_pos(pos, token.alliance) + {BOARD_TILE_SIZE, BOARD_TILE_SIZE}/2
				arrow.target = get_board_pos_screen_pos(target_pos, opposite_alliance) + {BOARD_TILE_SIZE, BOARD_TILE_SIZE}/2
				vfx: VFX
				vfx.done = false
				vfx.start_time = rl.GetTime()
				vfx.subtype = arrow
				sa.append(&g.active_vfx, vfx)

				shooting_state: Archer_Shooting
				shooting_state.target = target_pos
				token.state = shooting_state
			} else {
				fmt.println("couldnt find target")
				token.finished_action = true
			}
		case Archer_Shooting:
			if sa.len(g.active_vfx) <= 0 {
				token.finished_action = true
				opposite_alliance := token.alliance == .Player ? Alliance.Enemy : Alliance.Player
				if target_token, target_token_ok := get_token_from_board_pos(variant.target, opposite_alliance); target_token_ok {
					target_token.type = .None
				}

				token.finished_action = true
			}
		}
	case .Swordsman:
		/* /\* SWORDSMAN_ACTION_DURATION :: 0.5 *\/ */
		/* // TODO (rhoe) set action to finished before moving token so it gets copied to the new place */
		/* token.finished_action = true */
		/* if pos.y > 0 { */
		/* 	token_copy := token^ */
		/* 	g.board[pos.x][pos.y].type = .None */

		/* 	move_dir := token.dir == .Up ? -1 : 1 */
		/* 	new_y := token.dir == .Up ? pos.y-1 : pos.y+1 */
		/* 	if new_y < BOARD_ROWS-1 || new_y >= 0 { */
		/* 		g.board[pos.x][pos.y].type = .None */
		/* 		g.board[pos.x][pos.y + move_dir] = token_copy */
		/* 	} */
		/* } */
		/* return true */
	}
*/

	/* return false */
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
			}

			rl.DrawText(rl.TextFormat("(%d, %d)", x, y), i32(rect.x), i32(rect.y), 24, rl.GREEN)
			rl.DrawText(rl.TextFormat("%d", board_token.life), i32(rect.x), i32(rect.y+24), 24, rl.RED)
		}
	}

	////////////
	// DRAW ENEMY BOARD TOKENS
	for x in 0..<BOARD_COLUMNS {
		for y in 0..<BOARD_ROWS {

			// TODO (rhoe) enemy tokens are placed reverse to player tokens so
			//             pos {0, 0} is front right
			
			/* x_pos := (BOARD_COLUMNS-1) - x */
			/* y_pos := (BOARD_ROWS-1) - y */
			x_pos := x
			y_pos := y
			board_token := g.enemy_rows[x_pos][y_pos]
			rect: Rect
			rect.x = f32(x) * BOARD_TILE_SIZE
			rect.y = (f32(y) * BOARD_TILE_SIZE) + BOARD_OFFSET_Y
			rect.width = BOARD_TILE_SIZE
			rect.height = BOARD_TILE_SIZE
			if board_token.type != .None {
				rl.DrawTexturePro(g.atlas_texture, atlas_textures[board_token.texture_name].rect, rect, {}, 0, rl.WHITE)
			}

			rl.DrawText(rl.TextFormat("(%d, %d)", x_pos, y_pos), i32(rect.x), i32(rect.y), 14, rl.GREEN)
			rl.DrawText(rl.TextFormat("%d", board_token.life), i32(rect.x), i32(rect.y+24), 24, rl.RED)

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
	// DRAW LIVES
	rl.DrawText(rl.TextFormat("enemy lives:%d", g.enemy_lives), 0, 0, 20, rl.RED)
	rl.DrawText(rl.TextFormat("player lives:%d", g.player_lives), 400, 0, 20, rl.RED)

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

	g.round_state = Playing_Tokens_State{}

	// setup game board
	for x in 0..<BOARD_COLUMNS {
		for y in 0..<BOARD_ROWS {
			g.player_rows[x][y] = Board_Token{type=.None}
			g.enemy_rows[x][y] = Board_Token{type=.None}
		}
	}

	for _ in 0..<PLAYER_MAX_HAND_SIZE {
		token_type := Board_Token_Type(rl.GetRandomValue(1, len(Board_Token_Type)-1))
		sa.append(&g.player.current_hand, create_board_token(token_type, .Player))

	}

	// setup enemies
	/* for x in 0..<BOARD_COLUMNS { */
	/* 	for y in 0..<BOARD_ROWS { */
	/* 		token := create_board_token(.Archer, .Enemy) */
	/* 		/\* token.dir = .Down *\/ */
	/* 		g.enemy_rows[x][y] = token */
	/* 	} */
	/* } */
	for _ in 0..<4 {
		y := int(rl.GetRandomValue(0, 1))
		x := int(rl.GetRandomValue(0, BOARD_COLUMNS-1))
		token := create_board_token(.Archer, .Enemy)
		g.enemy_rows[x][y] = token
	}

	/* token := create_board_token(.Archer, .Enemy) */
	/* g.enemy_rows[0][0] = token */

	g.player_lives = 10
	g.enemy_lives = 10


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
