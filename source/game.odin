/*
thoughts:
instead of the current reading order of execution (left to right row by row)
we could have an initiative system
*/

package game

import "core:fmt"
import "core:math/linalg"
import sa "core:container/small_array"
import rl "vendor:raylib"

_ :: fmt

BOARD_COLUMNS :: 5
BOARD_ROWS :: 5
BOARD_TILE_SIZE :: 64
PLAYER_HAND_Y_START :: 400
PLAYER_HAND_X_START :: 0
PLAYER_MAX_HAND_SIZE :: 5

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

Init_State :: struct {
}

Token_State :: union {
	Init_State,
	Archer_Shooting,
	Archer_Moving,
	Swordsman_Moving,
}

Token_Direction :: enum {
	Up,
	Down,
}

Board_Token :: struct {
	type: Board_Token_Type,
	texture_name: Texture_Name,
	alliance: Alliance,
	state: Token_State,
	dir: Token_Direction,
	/* initialized: bool, */
	finished_action: bool,
}

Player_State :: struct {
	current_hand: sa.Small_Array(PLAYER_MAX_HAND_SIZE, Board_Token),

	hovered_token_id: int, 
	hovered_token_active: bool,
	dragged_token_id: int, 
	dragged_token_active: bool,
	dragged_token_offset: Vec2,
}

Doing_Enemy_Actions_State :: struct {
	start: f64,
	current_board_pos: Board_Pos,
}
Getting_Tokens_State :: struct {
}
Playing_Tokens_State :: struct {
}
Doing_Actions_State :: struct {
	start: f64,
	current_board_pos: Board_Pos,
	/* doing_action_action_initialized: bool, */
}

Game_Round_State :: union {
	Getting_Tokens_State,
	Playing_Tokens_State,
	Doing_Actions_State,
	Doing_Enemy_Actions_State,
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
	board: [BOARD_COLUMNS][BOARD_ROWS]Board_Token,
	player: Player_State,
	round_state: Game_Round_State,

	/* doing_action_start: f64, */
	/* doing_action_current_board_pos: Board_Pos, */
	/* doing_action_action_initialized: bool, */

	active_vfx: sa.Small_Array(MAX_ACTIVE_VFX, VFX),
	/* archer_arrow_active: bool, */
	/* archer_arrow_target: Vec2, */
	/* archer_arrow_pos: Vec2, */
}

g: ^Game_Memory

create_board_token :: proc(type: Board_Token_Type, alliance: Alliance) -> Board_Token {
	token: Board_Token
	token.type = type
	token.alliance = alliance
	switch type {
	case .None:
	case .Archer:
		token.texture_name = .Archer
		/* token.state = archer_state */
	case .Swordsman:
		token.texture_name = .Test_Face
	}

	return token
}

// get board token from given position
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
	token := &g.board[pos.x][pos.y]
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


// searches for next token which is:
// - not type .None
// - matching alliance
// - not finished_action
find_next_token :: proc(start: Board_Pos, alliance: Alliance) -> (Board_Pos, bool) {
	next_pos := start
	for {
		token: ^Board_Token
		token_pos_ok: bool
		if token, token_pos_ok = get_token_from_board_pos(next_pos); !token_pos_ok {
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
						rect.y = f32(y) * BOARD_TILE_SIZE
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
					g.board[valid_board_position.x][valid_board_position.y] = sa.get(g.player.current_hand, g.player.dragged_token_id)
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

			// TODO (rhoe) here we reset all tokens to not finished so they can run their actions again
			for x in 0..<BOARD_COLUMNS {
				for y in 0..<BOARD_ROWS {
					if token, token_valid := get_token_from_board_pos({x, y}); token_valid {
						token.finished_action = false
					}
				}
			}
			

			doing_actions: Doing_Actions_State
			/* doing_actions.current_board_pos = {0, 0} */
			/* doing_actions.start = rl.GetTime() */
			/* g.round_state = doing_actions */

			/* if token, token_ok := get_token_from_board_pos(doing_actions.current_board_pos); token_ok { */
			/* 	token.state = Init_State{} */
			/* } */

			found_next_token: bool
			doing_actions.current_board_pos, found_next_token = find_next_token({0, 0}, .Player)
			if found_next_token {
				token, _ := get_token_from_board_pos(doing_actions.current_board_pos)
				token.state = Init_State{}
				doing_actions.start = rl.GetTime()
				g.round_state = doing_actions
			}
		}
	case Doing_Actions_State:

		/*
1. call do_board_pos_action with current position
  if it returns false continue
  if it returns true the action is done and we move on to the next one

the action (for example update archer) is responsible for "declaring" when its done

maybe we want to have a bit of pause before and after an action begins to make the flow more uniform. This way the flow would be:
1. pause before action
2. action duration
3. pause after action
*/
		if do_board_pos_action(state.current_board_pos, state.start) {
			found_next_token := false
			state.current_board_pos, found_next_token = find_next_token(increment_board_position(state.current_board_pos), .Player)
			if !found_next_token {

				// INITIALIZE ENEMY ACTIONS STATE
				if enemy_pos, found_enemy :=  find_next_token({0, 0}, .Enemy); found_enemy {
					enemy_actions_state := Doing_Enemy_Actions_State{}
					enemy_actions_state.current_board_pos = enemy_pos
					token, _ := get_token_from_board_pos(enemy_actions_state.current_board_pos)
					token.state = Init_State{}
					enemy_actions_state.start = rl.GetTime()
					g.round_state = enemy_actions_state
				}
				break
			}

			token, _ := get_token_from_board_pos(state.current_board_pos)
			token.state = Init_State{}

			state.start = rl.GetTime()
		}

	case Doing_Enemy_Actions_State:
		if do_board_pos_action(state.current_board_pos, state.start) {

			fmt.println("finding next enemy action:", state.current_board_pos)
			found_next_token := false
			state.current_board_pos, found_next_token = find_next_token(increment_board_position(state.current_board_pos), .Enemy)
			if !found_next_token {
				fmt.println("finished doing enemy actions")
				g.round_state = Playing_Tokens_State{}
				break
			}

			token, _ := get_token_from_board_pos(state.current_board_pos)
			token.state = Init_State{}

			state.start = rl.GetTime()
		}
	}

	update_vfx()
}

// returns true if action is done
// TODO (rhoe) probably a bit of a confusion return var
do_board_pos_action :: proc(pos: Board_Pos, start_time: f64) -> bool {

	token, ok := get_token_from_board_pos(pos)
	if !ok do return true

	fmt.println("doing token action for:", pos, token)

	if token.finished_action do return true

	switch token.type {
	case .None:
		return true
	case .Archer:
		#partial switch variant in token.state {
		case Init_State:

			// handle initialization of archer action here
			/* token.initialized = true */
			found_target := false
			enemy_pos: Board_Pos

			y := token.dir == .Up ? pos.y-1 : pos.y+1
			move_dir := token.dir == .Up ? -1 : 1

			/* for y; y < BOARD_ROWS-1; y += move_dir { */
			for {
				if y < 0 || y > BOARD_ROWS-1 do break

				// do thing
				test_token := g.board[pos.x][y]
				if test_token.alliance != token.alliance && test_token.type != .None {
					fmt.println("found target:", test_token.alliance)
					found_target = true
					enemy_pos = {pos.x, y}
					break
				}

				y += move_dir
			}

			/* for y := pos.y-1; y >= 0; y -= 1 { */
			/* 	test_token := g.board[pos.x][y] */
			/* 	if test_token.alliance != .Player && test_token.type != .None { */
			/* 		// found enemy */
			/* 		found_enemy = true */
			/* 		enemy_pos = {pos.x, y} */
			/* 		break */
			/* 	} */
			/* } */

			if found_target {
				sa.clear(&g.active_vfx)
				arrow: Arrow_VFX
				arrow.t = 0
				arrow.start = {f32(pos.x * BOARD_TILE_SIZE), f32(pos.y * BOARD_TILE_SIZE)} + {BOARD_TILE_SIZE, BOARD_TILE_SIZE}/2
				arrow.target = {f32(enemy_pos.x * BOARD_TILE_SIZE), f32((enemy_pos.y) * BOARD_TILE_SIZE)} + {BOARD_TILE_SIZE, BOARD_TILE_SIZE}/2
				vfx: VFX
				vfx.done = false
				vfx.start_time = rl.GetTime()
				vfx.subtype = arrow
				sa.append(&g.active_vfx, vfx)

				shooting_state: Archer_Shooting
				shooting_state.target = enemy_pos
				token.state = shooting_state
			} else {
				moving_state: Archer_Moving
				moving_state.target = enemy_pos
				token.state = moving_state
			}
			
			return false
		case Archer_Shooting:
			if sa.len(g.active_vfx) <= 0 {
				token.finished_action = true
				if target_token, target_token_ok := get_token_from_board_pos(variant.target); target_token_ok {
					target_token.type = .None
				}
				return true
			}
			return false
		case Archer_Moving:
			// TODO (rhoe) set action to finished before moving token so it gets copied to the new place
			token.finished_action = true
			if pos.y > 0 && pos.y < BOARD_ROWS-1 {
				token_copy := token^
				move_dir := token.dir == .Up ? -1 : 1
				g.board[pos.x][pos.y].type = .None
				g.board[pos.x][pos.y + move_dir] = token_copy
			}
			return true
		}
	case .Swordsman:
		/* SWORDSMAN_ACTION_DURATION :: 0.5 */
		// TODO (rhoe) set action to finished before moving token so it gets copied to the new place
		token.finished_action = true
		if pos.y > 0 {
			token_copy := token^
			g.board[pos.x][pos.y].type = .None

			move_dir := token.dir == .Up ? -1 : 1
			new_y := token.dir == .Up ? pos.y-1 : pos.y+1
			if new_y < BOARD_ROWS-1 || new_y >= 0 {
				g.board[pos.x][pos.y].type = .None
				g.board[pos.x][pos.y + move_dir] = token_copy
			}
		}
		return true
	}

	return false
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
		for y in 0..<BOARD_ROWS {
			x_pos := x * BOARD_TILE_SIZE
			y_pos := y * BOARD_TILE_SIZE
			rl.DrawRectangleLines(i32(x_pos), i32(y_pos), BOARD_TILE_SIZE, BOARD_TILE_SIZE, rl.BLACK)
		}
	}

	////////////
	// DRAW BOARD TOKENS
	for x in 0..<BOARD_COLUMNS {
		for y in 0..<BOARD_ROWS {
			board_token := g.board[x][y]
			if board_token.type == .None do continue

			rect: Rect
			rect.x = f32(x) * BOARD_TILE_SIZE
			rect.y = f32(y) * BOARD_TILE_SIZE
			rect.width = BOARD_TILE_SIZE
			rect.height = BOARD_TILE_SIZE
			rl.DrawTexturePro(g.atlas_texture, atlas_textures[board_token.texture_name].rect, rect, {}, 0, rl.WHITE)
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
			g.board[x][y] = Board_Token{type=.None}
		}
	}

	for _ in 0..<PLAYER_MAX_HAND_SIZE {
		token_type := Board_Token_Type(rl.GetRandomValue(1, len(Board_Token_Type)-1))
		sa.append(&g.player.current_hand, create_board_token(token_type, .Player))

	}

	// setup enemies
	for _ in 0..<4 {
		y := int(rl.GetRandomValue(0, 1))
		x := int(rl.GetRandomValue(0, BOARD_COLUMNS-1))
		token := create_board_token(.Archer, .Enemy)
		token.dir = .Down
		g.board[x][y] = token
	}

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
