debug_status = 0
debug_mod_name = "BlackMarket2"
debug_file = debug_mod_name .. "-debug.txt"
prices_file = debug_mod_name .. "-prices.csv"
specials_file = debug_mod_name .. "-specials.txt"
require("utils")
require("config")
require("mod-gui")

configure_settings()

local table = require('__flib__.table')
local gui = require('__flib__.gui')

local trader_type = { item=1, fluid=2, energy=3, "item", "fluid", "energy" }
local energy_name = "market-energy" -- name of fake energy item

local trader_signals =
	{
		auto_all = {type="virtual",name="signal-market-auto-all"},
		auto_sell = {type="virtual",name="signal-market-auto-sell"},
		auto_buy = {type="virtual",name="signal-market-auto-buy"},
	}

--------------------------------------------------------------------------------------
function format_money( n )
	if n == nil then return( "0u" ) end
	
	local neg, mega
	
	if n > 1e12 then
		n = math.floor(n/1e6)
		mega = true
	else
		mega = false
	end
	
	if n < 0 then
		n = -n
		neg = true
	else
		neg = false
	end
	
	local s = tostring(math.floor(n+0.5))
	local s2 = ""
	local l = string.len(s)
	local i = l+1
	
	while i > 4 do
		i = i-3	
		s2 =  thousands_separator .. string.sub(s,i,i+2) .. s2
	end
	
	if i > 1 then
		s2 =  string.sub(s,1,i-1) .. s2
	end
	
	if mega then
		s2 = s2 .. "Mu"
	else
		s2 = s2 .. "u"
	end
	
	if neg then
		return( "-" .. s2 )
	else
		return( s2 )
	end
end

--------------------------------------------------------------------------------------
function format_evolution( evol )
	if evol == nil or evol == 0 then
		return("=")
	elseif evol > 0 then
		return("+")
	else
		return("-")
	end
end

--------------------------------------------------------------------------------------
local function clean_gui(gui)
	for _, guiname in pairs( gui.children_names ) do
		gui[guiname].destroy()
	end
end

--------------------------------------------------------------------------------------
local function build_bar( player )
	local gui_parent = mod_gui.get_button_flow(player)
	local gui1 = gui_parent.flw_blkmkt
	
	if gui1 == nil then
		local player_mem = global.player_mem[player.index]
		-- debug_print("create gui player" .. player.name)
		gui1 = gui_parent.add({type = "flow", name = "flw_blkmkt", direction = "horizontal", style = "horizontal_flow_blkmkt_style"})
		gui1.add({type = "sprite-button", name = "but_blkmkt_main", sprite = "sprite_main_blkmkt", style = "sprite_main_blkmkt_style"})				
		player_mem.but_blkmkt_credits = gui1.add({type = "button", name = "but_blkmkt_credits", caption = format_money(0), style = "button_blkmkt_credits_style"})				
	end
end

--------------------------------------------------------------------------------------
local function update_bar( player )
	local player_mem = global.player_mem[player.index]
	
	if player_mem.cursor_name == nil or global.prices_computed or not player_mem.but_blkmkt_credits.caption == nil then
		local force_mem = global.force_mem[player.force.name]
		player_mem.but_blkmkt_credits.caption = format_money(force_mem.credits)
	else
		local price = global.prices[player_mem.cursor_name]
		if price == nil then 
			player_mem.but_blkmkt_credits.caption = "=NONE"
		else
			player_mem.but_blkmkt_credits.caption = "~" .. format_money(price.current) .. " " .. format_evolution(price.evolution)
			-- debug_print("~:",price.current)
		end
	end
end

--------------------------------------------------------------------------------------
local function update_bars( force )
	for _, player in pairs(force.players) do
		if player.connected then
			update_bar(player)
		end
	end
end

--------------------------------------------------------------------------------------
local function build_menu_gen( player, player_mem, open_or_close )
	local gui_parent = mod_gui.get_frame_flow(player)
	if open_or_close == nil then
		open_or_close = (gui_parent.frm_blkmkt_gen == nil)
	end
	
	if gui_parent.frm_blkmkt_gen then
		gui_parent.frm_blkmkt_gen.destroy()
	end
	
	if open_or_close and not global.prices_computed then
		local gui1, gui2, gui3
		gui1 = gui_parent.add({type = "frame", name = "frm_blkmkt_gen", caption = {"blkmkt-gui-blkmkt"}, style = "frame_blkmkt_style"})
		gui1 = gui1.add({type = "flow", name = "flw_blkmkt_gen", direction = "vertical", style = "vertical_flow_blkmkt_style"})
		
		gui2 = gui1.add({type = "flow", direction = "horizontal", style = "horizontal_flow_blkmkt_style"})
		gui2.add({type = "label", caption = {"blkmkt-gui-gen-prices"}, style = "label_blkmkt_style"})
		gui2.add({type = "button", name = "but_blkmkt_gen_show_prices", caption = {"blkmkt-gui-gen-show-prices"}, 
			tooltip = {"blkmkt-gui-gen-show-prices-tt"}, style = "button_blkmkt_style"})
		gui2.add({type = "button", name = "but_blkmkt_gen_export_prices", caption = {"blkmkt-gui-gen-export-prices"}, 
			tooltip = {"blkmkt-gui-gen-export-prices-tt"}, style = "button_blkmkt_style"})
		gui2.add({type = "button", name = "but_blkmkt_gen_rescan_prices", caption = {"blkmkt-gui-gen-rescan-prices"}, 
			tooltip = {"blkmkt-gui-gen-rescan-prices-tt"}, style = "button_blkmkt_style"})
			
		gui2 = gui1.add({type = "flow", direction = "horizontal", style = "horizontal_flow_blkmkt_style"})
		player_mem.chk_blkmkt_gen_pause = gui2.add({type = "checkbox", name = "chk_blkmkt_gen_pause", caption = {"blkmkt-gui-gen-pause"}, state = false, 
			tooltip = {"blkmkt-gui-gen-pause-tt"}, style = "checkbox_blkmkt_style"})
		gui2.add({type = "button", name = "but_blkmkt_gen_auto_all", caption = {"blkmkt-gui-gen-auto-all"}, 
			tooltip = {"blkmkt-gui-gen-auto-all-tt"}, style = "button_blkmkt_style"})
		gui2.add({type = "button", name = "but_blkmkt_gen_auto_none", caption = {"blkmkt-gui-gen-auto-none"}, 
			tooltip = {"blkmkt-gui-gen-auto-none-tt"}, style = "button_blkmkt_style"})
			
		gui2 = gui1.add({type = "flow", direction = "horizontal", style = "horizontal_flow_blkmkt_style"})
		gui2.add({type = "button", name = "but_blkmkt_gen_sell_now", caption = {"blkmkt-gui-gen-sell-now"}, 
			tooltip = {"blkmkt-gui-gen-sell-now-tt",global.tax_rates[0]}, style = "button_blkmkt_style"})
		gui2.add({type = "button", name = "but_blkmkt_gen_buy_now", caption = {"blkmkt-gui-gen-buy-now"}, 
			tooltip = {"blkmkt-gui-gen-buy-now-tt",global.tax_rates[0]}, style = "button_blkmkt_style"})
			
		gui2 = gui1.add({type = "flow", direction = "horizontal", style = "horizontal_flow_blkmkt_style"})
		gui2.add({type = "button", name = "but_blkmkt_gen_period_down", caption = "<", style = "button_blkmkt_style"})
		gui2.add({type = "button", name = "but_blkmkt_gen_period_up", caption = ">", style = "button_blkmkt_style"})
		player_mem.lbl_blkmkt_gen_period = gui2.add({type = "label", name = "lbl_blkmkt_gen_period", caption = {"blkmkt-gui-gen-period", 0,0}, 
			tooltip = {"blkmkt-gui-gen-period-tt"}, style = "label_blkmkt_style"})
		gui2.add({type = "button", name = "but_blkmkt_gen_period_set", caption = {"blkmkt-gui-gen-period-set"}, 
			tooltip = {"blkmkt-gui-gen-period-set-tt"}, style = "button_blkmkt_style"})

		gui2 = gui1.add({type = "table", column_count = 2, style = "table_blkmkt_style"})
		
		gui2.add({type = "label", caption = {"blkmkt-gui-gen-credits"}, 
			tooltip = {"blkmkt-gui-gen-credits-tt"}, style = "label_blkmkt_style"})
		player_mem.lbl_blkmkt_gen_credits = gui2.add({type = "label", name = "lbl_blkmkt_gen_credits", 
			tooltip = {"blkmkt-gui-gen-credits-tt"}, style = "label_blkmkt_style"})
		
		gui2.add({type = "label", caption = {"blkmkt-gui-gen-sales"}, 
			tooltip = {"blkmkt-gui-gen-sales-tt"}, style = "label_blkmkt_style"})
		player_mem.lbl_blkmkt_gen_sales = gui2.add({type = "label", name = "lbl_blkmkt_gen_sales", 
			tooltip = {"blkmkt-gui-gen-sales-tt"}, style = "label_blkmkt_style"})
		
		gui2.add({type = "label", caption = {"blkmkt-gui-gen-sales-taxes"}, 
			tooltip = {"blkmkt-gui-gen-sales-taxes-tt"}, style = "label_blkmkt_style"})
		player_mem.lbl_blkmkt_gen_sales_taxes = gui2.add({type = "label", name = "lbl_blkmkt_gen_sales_taxes", 
			tooltip = {"blkmkt-gui-gen-sales-taxes-tt"}, style = "label_blkmkt_style"})
		
		gui2.add({type = "label", caption = {"blkmkt-gui-gen-purchases"}, 
			tooltip = {"blkmkt-gui-gen-purchases-tt"}, style = "label_blkmkt_style"})
		player_mem.lbl_blkmkt_gen_purchases = gui2.add({type = "label", name = "lbl_blkmkt_gen_purchases", 
			tooltip = {"blkmkt-gui-gen-purchases-tt"}, style = "label_blkmkt_style"})
		
		gui2.add({type = "label", caption = {"blkmkt-gui-gen-purchases-taxes"}, 
			tooltip = {"blkmkt-gui-gen-purchases-taxes-tt"}, style = "label_blkmkt_style"})
		player_mem.lbl_blkmkt_gen_purchases_taxes = gui2.add({type = "label", name = "lbl_blkmkt_gen_purchases_taxes", 
			tooltip = {"blkmkt-gui-gen-purchases-taxes-tt"}, style = "label_blkmkt_style"})
		
		gui2.add({type = "label", caption = {"blkmkt-gui-gen-average-taxes"}, 
			tooltip = {"blkmkt-gui-gen-average-taxes-tt"}, style = "label_blkmkt_style"})
		player_mem.lbl_blkmkt_gen_tax_rate = gui2.add({type = "label", name = "lbl_blkmkt_gen_tax_rate", 
			tooltip = {"blkmkt-gui-gen-average-taxes-tt"}, style = "label_blkmkt_style"})
		
		gui2.add({type = "label", caption = {"blkmkt-gui-gen-credits-lastday"}, 
			tooltip = {"blkmkt-gui-gen-credits-lastday-tt"}, style = "label_blkmkt_style"})
		player_mem.lbl_blkmkt_gen_credits_lastday = gui2.add({type = "label", name = "lbl_blkmkt_gen_credits_lastday", 
			tooltip = {"blkmkt-gui-gen-credits-lastday-tt"}, style = "label_blkmkt_style"})
		
		gui1.add({type = "label", caption = {"blkmkt-gui-gen-transactions"}, 
			tooltip = {"blkmkt-gui-gen-transactions-tt"}, style = "label_blkmkt_style"})
		gui2 = gui1.add({type = "flow", name = "flw_blkmkt_gen_trans", direction = "horizontal", style = "horizontal_flow_blkmkt_style"})
		gui2 = gui2.add({type = "scroll-pane", name = "scr_blkmkt_gen_trans", vertical_scroll_policy = "auto"})
		gui2.style.maximal_height = 150
		player_mem.scr_blkmkt_gen_trans = gui2
		
		gui1.add({type = "button", name = "but_blkmkt_gen_close", caption = {"blkmkt-gui-close"}, style = "button_blkmkt_style"})
	end
end

--------------------------------------------------------------------------------------
local function update_menu_gen( player, player_mem )
	local gui_parent = mod_gui.get_frame_flow(player)
	if gui_parent.frm_blkmkt_gen == nil or global.prices_computed then
		return
	end
	
	local force_mem = global.force_mem[player.force.name]
	player_mem.chk_blkmkt_gen_pause.state = force_mem.pause
	player_mem.lbl_blkmkt_gen_period.caption = {"blkmkt-gui-gen-period", force_mem.period,global.tax_rates[force_mem.period]}
	
	player_mem.lbl_blkmkt_gen_credits.caption = format_money(force_mem.credits)
	player_mem.lbl_blkmkt_gen_sales.caption = format_money(force_mem.sales)
	player_mem.lbl_blkmkt_gen_sales_taxes.caption = format_money(force_mem.sales_taxes)
	player_mem.lbl_blkmkt_gen_purchases.caption = format_money(force_mem.purchases)
	player_mem.lbl_blkmkt_gen_purchases_taxes.caption = format_money(force_mem.purchases_taxes)
	player_mem.lbl_blkmkt_gen_tax_rate.caption = force_mem.tax_rate .. "%"
	player_mem.lbl_blkmkt_gen_credits_lastday.caption = format_money(force_mem.credits_lastday) .. string.format(" (%+2.2f%%)", force_mem.var_lastday)
	
	clean_gui(player_mem.scr_blkmkt_gen_trans)
	local gui2 = player_mem.scr_blkmkt_gen_trans.add({type = "table", name = "tab_blkmkt_gen_trans", column_count = 2, style = "table_blkmkt_style"})
	
	gui2.add({type = "label", caption = "name", style = "label_blkmkt_style"})
	gui2.add({type = "label", caption = "count", style = "label_blkmkt_style"})
	
	for name, transaction in pairs(force_mem.transactions) do
		-- debug_print(n, " ", name)
		if transaction.type == "item" then
			gui2.add({type = "sprite-button", sprite = "item/" .. name, style = "sprite_obj_blkmkt_style"})
		elseif transaction.type == "fluid" then
			gui2.add({type = "sprite-button", sprite = "fluid/" .. name, style = "sprite_obj_blkmkt_style"})
		else
			gui2.add({type = "sprite-button", sprite = "sprite_energy_blkmkt", style = "sprite_obj_blkmkt_style"})
		end
			
		gui2.add({type = "label", caption = math.floor(transaction.count), style = "label_blkmkt_style"})
	end
end

--------------------------------------------------------------------------------------
local function build_menu_trader( player, player_mem, open_or_close )
	local gui_parent = mod_gui.get_frame_flow(player)
	if open_or_close == nil then
		open_or_close = (gui_parent.frm_blkmkt_trader == nil)
	end
	
	if gui_parent.frm_blkmkt_trader then
		gui_parent.frm_blkmkt_trader.destroy()
		player_mem.frm_blkmkt_trader = nil
	end
	
	if open_or_close and not global.prices_computed then
		local trader = player_mem.opened_trader
		local gui1, gui2, gui3
		gui1 = gui_parent.add({type = "frame", name = "frm_blkmkt_trader", style = "frame_blkmkt_style"})
		player_mem.frm_blkmkt_trader = gui1
		gui1 = gui1.add({type = "flow", name = "flw_blkmkt_trader", direction = "vertical", style = "vertical_flow_blkmkt_style"})
		
		gui2 = gui1.add({type = "flow", direction = "horizontal", style = "horizontal_flow_blkmkt_style"})
		player_mem.chk_blkmkt_trader_auto = gui2.add({type = "checkbox", name = "chk_blkmkt_trader_auto", caption = {"blkmkt-gui-trader-auto"}, state = false, 
			tooltip = {"blkmkt-gui-trader-auto-tt"}, style = "checkbox_blkmkt_style"})
		if trader.sell_or_buy then
			gui2.add({type = "button", name = "but_blkmkt_trader_now", caption = {"blkmkt-gui-trader-sell-now"}, 
				tooltip = {"blkmkt-gui-trader-sell-now-tt",global.tax_rates[0]}, style = "button_blkmkt_style"})
		else
			gui2.add({type = "button", name = "but_blkmkt_trader_now", caption = {"blkmkt-gui-trader-buy-now"}, 
				tooltip = {"blkmkt-gui-trader-buy-now-tt",global.tax_rates[0]}, style = "button_blkmkt_style"})
		end
		
		-- if trader.sell_or_buy and trader.type == trader_type.energy then
			-- player_mem.chk_blkmkt_trader_daylight = gui2.add({type = "checkbox", name = "chk_blkmkt_trader_daylight", caption = {"blkmkt-gui-trader-daylight"}, state = false, 
				-- tooltip = {"blkmkt-gui-trader-daylight-tt"}, style = "checkbox_blkmkt_style"})
		-- end
		
		gui2 = gui1.add({type = "flow", direction = "horizontal", style = "horizontal_flow_blkmkt_style"})
		gui2.add({type = "button", name = "but_blkmkt_trader_period_down", caption = "<", style = "button_blkmkt_style"})
		gui2.add({type = "button", name = "but_blkmkt_trader_period_up", caption = ">", style = "button_blkmkt_style"})
		player_mem.lbl_blkmkt_trader_period = gui2.add({type = "label", name = "lbl_blkmkt_trader_period", caption = {"blkmkt-gui-trader-period", 0,0}, 
			tooltip = {"blkmkt-gui-trader-period-tt"}, style = "label_blkmkt_style"})
		
		gui2 = gui1.add({type = "table", column_count = 2, style = "table_blkmkt_style"})
		
		gui2.add({type = "label", caption = {"blkmkt-gui-trader-money-tot"}, 
			tooltip = {"blkmkt-gui-trader-money-tot-tt"}, style = "label_blkmkt_style"})
		player_mem.lbl_blkmkt_trader_money_tot = gui2.add({type = "label", name = "lbl_blkmkt_trader_money_tot", 
			tooltip = {"blkmkt-gui-trader-money-tot-tt"}, style = "label_blkmkt_style"})
		
		gui2.add({type = "label", caption = {"blkmkt-gui-trader-taxes-tot"}, 
			tooltip = {"blkmkt-gui-trader-taxes-tot-tt"}, style = "label_blkmkt_style"})
		player_mem.lbl_blkmkt_trader_taxes_tot = gui2.add({type = "label", name = "lbl_blkmkt_trader_taxes_tot", 
			tooltip = {"blkmkt-gui-trader-taxes-tot-tt"}, style = "label_blkmkt_style"})
		
		gui2.add({type = "label", caption = {"blkmkt-gui-trader-money-period"}, 
			tooltip = {"blkmkt-gui-trader-money-period-tt"}, style = "label_blkmkt_style"})
		player_mem.lbl_blkmkt_trader_money_period = gui2.add({type = "label", name = "lbl_blkmkt_trader_money_period", 
			tooltip = {"blkmkt-gui-trader-money-period-tt"}, style = "label_blkmkt_style"})
		
		gui2.add({type = "button", name = "but_blkmkt_trader_reset", caption = {"blkmkt-gui-trader-reset"}, style = "button_blkmkt_style"})
		player_mem.lbl_blkmkt_trader_dhour = gui2.add({type = "label", name = "lbl_blkmkt_trader_dhour", 
			tooltip = {"blkmkt-gui-trader-hours-tt"}, style = "label_blkmkt_style"})
		
		gui2.add({type = "label", caption = {"blkmkt-gui-trader-money"}, 
			tooltip = {"blkmkt-gui-trader-money-tt"}, style = "label_blkmkt_style"})
		player_mem.lbl_blkmkt_trader_money = gui2.add({type = "label", name = "lbl_blkmkt_trader_money", 
			tooltip = {"blkmkt-gui-trader-money-tt"}, style = "label_blkmkt_style"})
		
		gui2.add({type = "label", caption = {"blkmkt-gui-trader-taxes"}, 
			tooltip = {"blkmkt-gui-trader-taxes-tt"}, style = "label_blkmkt_style"})
		player_mem.lbl_blkmkt_trader_taxes = gui2.add({type = "label", name = "lbl_blkmkt_trader_taxes", 
			tooltip = {"blkmkt-gui-trader-taxes-tt"}, style = "label_blkmkt_style"})
		
		gui2.add({type = "label", caption = {"blkmkt-gui-trader-money-average"}, 
			tooltip = {"blkmkt-gui-trader-money-average-tt"}, style = "label_blkmkt_style"})
		player_mem.lbl_blkmkt_trader_money_average = gui2.add({type = "label", name = "lbl_blkmkt_trader_money_average", 
			tooltip = {"blkmkt-gui-trader-money-average-tt"}, style = "label_blkmkt_style"})

		player_mem.but_blkmkt_trader_evaluate =  gui2.add({type = "button", name = "but_blkmkt_trader_evaluate", caption = {"blkmkt-gui-trader-evaluate"}, 
			tooltip = {"blkmkt-gui-trader-evaluate-tt"}, style = "button_blkmkt_style"})
		player_mem.lbl_blkmkt_trader_evaluation = gui2.add({type = "label", name = "lbl_blkmkt_trader_evaluation", 
			tooltip = {"blkmkt-gui-trader-evaluation-tt"}, style = "label_blkmkt_style"})

		-- gui2.add({type = "label", caption = {"blkmkt-gui-trader-price"}, 
			-- tooltip = {"blkmkt-gui-trader-price-tt"}, style = "label_blkmkt_style"})
		-- player_mem.lbl_blkmkt_trader_price = gui2.add({type = "label", name = "lbl_blkmkt_trader_price", 
			-- tooltip = {"blkmkt-gui-trader-price-tt"}, style = "label_blkmkt_style"})

		if trader.sell_or_buy then
			gui2.add({type = "label", caption = {"blkmkt-gui-trader-sold"}, 
				tooltip = {"blkmkt-gui-trader-sold-tt"}, style = "label_blkmkt_style"})
			gui3 = gui2.add({type = "flow", direction = "horizontal", style = "horizontal_flow_blkmkt_style"})
			player_mem.but_blkmkt_trader_sold = gui3.add({type = "sprite-button", name = "but_blkmkt_trader_sold", 
				tooltip = {"blkmkt-gui-trader-sold-tt"}, style = "sprite_obj_blkmkt_style"})
			player_mem.lbl_blkmkt_trader_sold = gui3.add({type = "label", name = "lbl_blkmkt_trader_sold", 
				tooltip = {"blkmkt-gui-trader-price-tt"}, style = "label_blkmkt_style"})
		else
			if trader.type == trader_type.item then
				-- gui2 = gui1.add({type = "flow", direction = "horizontal", style = "horizontal_flow_blkmkt_style"})
				gui2.add({type = "button", name = "but_blkmkt_trader_new", caption = {"blkmkt-gui-trader-new"}, style = "button_blkmkt_style"})
				gui2.add({type = "button", name = "but_blkmkt_trader_wipe", caption = {"blkmkt-gui-trader-wipe"}, style = "button_blkmkt_style"})
			end
			
			gui2.add({type = "label", caption = {"blkmkt-gui-trader-orders"}, 
				tooltip = {"blkmkt-gui-trader-orders-tt"}, style = "label_blkmkt_style"})
			player_mem.lbl_blkmkt_trader_orders = gui2.add({type = "label", name = "lbl_blkmkt_trader_orders", 
				tooltip = {"blkmkt-gui-trader-orders-tt"}, style = "label_blkmkt_style"})
				
			gui2 = gui1.add({type = "flow", name = "flw_blkmkt_trader_orders", direction = "horizontal", style = "horizontal_flow_blkmkt_style"})
			gui2 = gui2.add({type = "scroll-pane", name = "scr_blkmkt_trader_orders", vertical_scroll_policy = "auto"})
			gui2.style.maximal_height = 150
			player_mem.scr_blkmkt_trader_orders = gui2
		end
	end
end

--------------------------------------------------------------------------------------
local function update_menu_trader( player, player_mem, update_orders )
	local gui_parent = mod_gui.get_frame_flow(player)
	if gui_parent.frm_blkmkt_trader == nil or global.prices_computed then
		return
	end
	
	if player_mem == nil then
		player_mem = global.player_mem[player.index]
	end
	
	local trader = player_mem.opened_trader
	
	if trader.sell_or_buy then
		player_mem.frm_blkmkt_trader.caption = {"blkmkt-gui-trader-sell"}
	else
		player_mem.frm_blkmkt_trader.caption = {"blkmkt-gui-trader-buy"}
	end
	player_mem.chk_blkmkt_trader_auto.state = trader.auto
	-- if trader.sell_or_buy and trader.type == trader_type.energy then
		-- player_mem.chk_blkmkt_trader_daylight.state = trader.daylight
	-- end
		
	player_mem.lbl_blkmkt_trader_period.caption = {"blkmkt-gui-trader-period", trader.period,global.tax_rates[trader.period]}
	
	player_mem.lbl_blkmkt_trader_money_tot.caption = format_money(trader.money_tot)
	player_mem.lbl_blkmkt_trader_taxes_tot.caption = format_money(trader.taxes_tot) .. " (" .. trader.tax_rate_tot .. "%)"
	player_mem.lbl_blkmkt_trader_money_period.caption = format_money(trader.money_period)
	player_mem.lbl_blkmkt_trader_dhour.caption = {"blkmkt-gui-trader-hours", trader.period*math.floor(trader.dhour/trader.period)}
	player_mem.lbl_blkmkt_trader_money.caption = format_money(trader.money)
	player_mem.lbl_blkmkt_trader_taxes.caption = format_money(trader.taxes) .. " (" .. trader.tax_rate .. "%)"
	player_mem.lbl_blkmkt_trader_money_average.caption = {"blkmkt-gui-trader-perday", format_money(trader.money_average)}
	
	player_mem.lbl_blkmkt_trader_evaluation.caption = format_money(trader.evaluation) 
	-- if trader.price then
		-- player_mem.lbl_blkmkt_trader_price.caption = format_money(trader.price.current) .. " " .. format_evolution(trader.price.evolution)
	-- else
		-- player_mem.lbl_blkmkt_trader_price.caption = "-"
	-- end
	
	if trader.sell_or_buy then
		local sold_name = trader.sold_name
		if sold_name then
			if trader.type == trader_type.item then
				player_mem.but_blkmkt_trader_sold.sprite = "item/" .. sold_name
				player_mem.but_blkmkt_trader_sold.tooltip = game.item_prototypes[sold_name].localised_name
			elseif trader.type == trader_type.fluid then
				player_mem.but_blkmkt_trader_sold.sprite = "fluid/" .. sold_name
				player_mem.but_blkmkt_trader_sold.tooltip = game.fluid_prototypes[sold_name].localised_name
			else 
				player_mem.but_blkmkt_trader_sold.sprite = "sprite_energy_blkmkt"
				player_mem.but_blkmkt_trader_sold.tooltip = {"blkmkt-gui-energy"}
			end
			local price = global.prices[sold_name]
			if price then
				player_mem.lbl_blkmkt_trader_sold.caption = " " .. format_money(price.current) .. " " .. format_evolution(price.evolution)
			else
				player_mem.lbl_blkmkt_trader_sold.caption = " -"
			end
		else
			player_mem.but_blkmkt_trader_sold.sprite = "" 
			player_mem.lbl_blkmkt_trader_sold.caption = " -"
		end
	else
		player_mem.lbl_blkmkt_trader_orders.caption = format_money(trader.orders_tot)
				
		if update_orders then
			clean_gui(player_mem.scr_blkmkt_trader_orders)
			local gui2 = player_mem.scr_blkmkt_trader_orders.add({type = "table", name = "tab_blkmkt_trader_orders", column_count = 4, style = "table_blkmkt_style"})
			
			gui2.add({type = "label"})
			gui2.add({type = "label", caption = "name", style = "label_blkmkt_style"})
			gui2.add({type = "label", caption = "count", style = "label_blkmkt_style"})
			gui2.add({type = "label", caption = "price", style = "label_blkmkt_style"})
			
			function add_order(n,prefix,name,count,del_but)
				local price = global.prices[name]
				local current, evol
				if price then
					current = price.current
					evol = price.evolution
				else
					current = 0
					evol = 0
				end
				
				if del_but then
					gui2.add({type = "button", name = "but_blkmkt_ord_" .. string.format("%3d",n) .. name, caption = "X", style = "button_blkmkt_style"})
				else
					gui2.add({type = "label", style = "label_blkmkt_style"})
				end
				
				if prefix == nil then
					gui2.add({type = "sprite-button", name = "but_blkmkt_ori_" .. string.format("%3d",n) .. name, sprite = "sprite_energy_blkmkt", style = "sprite_obj_blkmkt_style"})
				else
					gui2.add({type = "sprite-button", name = "but_blkmkt_ori_" .. string.format("%3d",n) .. name, sprite = prefix .. name, style = "sprite_obj_blkmkt_style"})
				end
				
				gui2.add({type = "textfield", name = "but_blkmkt_orc_" .. string.format("%3d",n) .. name, text = count, style = "textfield_blkmkt_style"})
				gui2.add({type = "label", caption = format_money(current) .. " " .. format_evolution(evol), style = "label_blkmkt_style"})
			end

			if trader.type == trader_type.item then
				for n, order in pairs(trader.orders) do
					if n > 99 then break end
					add_order(n,"item/",order.name,order.count,true)
				end
			elseif trader.type == trader_type.fluid then
				local order = trader.orders[1]
				if order then
					add_order(1,"fluid/",order.name,order.count,false)
				end
			elseif trader.type == trader_type.energy then
				local order = trader.orders[1]
				if order then
					add_order(1,nil,energy_name,order.count,false)
				end
			end
		end
	end
end

--------------------------------------------------------------------------------------
local function build_menu_objects(player, open_or_close, ask_sel)
	local gui_parent = mod_gui.get_frame_flow(player)

	if open_or_close == nil then
		open_or_close = (gui_parent.frm_blkmkt_itml == nil)
	end
	
	if gui_parent.frm_blkmkt_itml then
		gui_parent.frm_blkmkt_itml.destroy()
	end
	
	if open_or_close and not global.prices_computed then
		local player_mem = global.player_mem[player.index]
		local main_window, item_table_holder, item_table
		main_window = mod_gui.get_frame_flow(player).add({type = "frame", name = "frm_blkmkt_itml", caption = {"blkmkt-gui-objects-list"}, style = "frame_blkmkt_style"})
		-- main_window = main_window.add({type = "empty-widget", ignored_by_interaction="true", name = "main_window_drag_handle", style = "flib_titlebar_drag_handle"})
		main_window = main_window.add({type = "flow", name = "flw_blkmkt_itml", direction = "vertical", style = "vertical_flow_blkmkt_style"})
		-- main_window.style.minimal_height = 500
		main_window.style.minimal_width = 380
		
		item_table_holder = main_window.add({type = "scroll-pane", name = "scr_blkmkt_itml", vertical_scroll_policy = "auto"}) -- , style = "scroll_pane_blkmkt_style"
		-- item_table_holder.style.maximal_height = 450
		player_mem.scr_blkmkt_recl = item_table_holder
		item_table = item_table_holder.add({type = "table", name = "tab_blkmkt_itml1", column_count = 6, style = "table_blkmkt_style"})
		
		local n = 0
		
		-- debug_print("group sel ", player_mem.group_sel_name)
		
		for name, group in pairs(global.groups) do
			if ask_sel == nil or ((ask_sel == "item" and group.item) or (ask_sel == "fluid" and group.fluid)) then
				if player_mem.group_sel_name == nil then
					player_mem.group_sel_name = name
				end
				item_table.add({type = "sprite-button", name = "but_blkmkt_ilg_" .. string.format("%3d",n) .. name, sprite = "item-group/" .. name, tooltip = name, style = "sprite_group_blkmkt_style"})
				n=n+1
			end
		end
		
		item_table = item_table_holder.add({type = "scroll-pane", name = "flib_naked_scroll_pane_no_padding", vertical_scroll_policy = "auto"})
		item_table.style.maximal_height = 200
		item_table = item_table.add({type = "table", name = "tab_blkmkt_itml2", column_count = 10, style = "table_blkmkt_style"})
		
		local group = global.groups[player_mem.group_sel_name].group
		
		n = 0
		
		if ask_sel == nil or ask_sel == "item" then
			for name, object in pairs(game.item_prototypes) do
				if object.group == group and not object.has_flag("hidden") and n <= 999 then
					local price = global.prices[name]
					if price then
						item_table.add({type = "sprite-button", name = "but_blkmkt_ili_" .. string.format("%3d",n) .. name, sprite = "item/" .. name, 
						tooltip = {"blkmkt-gui-tt-object-price",object.localised_name,format_money(price.current),format_evolution(price.evolution)}, style = "sprite_obj_blkmkt_style"})
						n=n+1
					end
				end
			end
		end
		
		if ask_sel == nil or ask_sel == "fluid" then
			for name, object in pairs(game.fluid_prototypes) do
				-- debug_print("build_menu_objects ", name, " ", object.group.name, " ", object.subgroup.name )
				if object.group == group and n <= 999 then
					local price = global.prices[name]
					if price then
						item_table.add({type = "sprite-button", name = "but_blkmkt_ili_" .. string.format("%3d",n) .. name, sprite = "fluid/" .. name, 
							tooltip = {"blkmkt-gui-tt-object-price",object.localised_name,format_money(price.current),format_evolution(price.evolution)}, style = "sprite_obj_blkmkt_style"})
						n=n+1
					end
				end
			end
		end
		
		main_window.add({type = "button", name = "but_blkmkt_itml_refresh", caption = {"blkmkt-gui-refresh"}, style = "button_blkmkt_style"})
		
		if ask_sel then
			main_window.add({type = "button", name = "but_blkmkt_itml_cancel", caption = {"blkmkt-gui-cancel"}, style = "button_blkmkt_style"})
		else
			main_window.add({type = "button", name = "but_blkmkt_itml_close", caption = {"blkmkt-gui-close"}, style = "button_blkmkt_style"})
		end
	end
end

--------------------------------------------------------------------------------------
local function update_gui(player,update_orders)
	if player.connected then
		local player_mem = global.player_mem[player.index]
		update_bar(player)
		update_menu_gen(player,player_mem)
		update_menu_trader(player,player_mem,update_orders)
		local gui_parent = mod_gui.get_frame_flow(player)
		if gui_parent.frm_blkmkt_itml then
			build_menu_objects(player,true,player_mem.ask_sel)
		end
	end
end

--------------------------------------------------------------------------------------
local function update_guis_force(force,update_orders)
	for _, player in pairs(force.players) do
		update_gui(player,update_orders)
	end
end

--------------------------------------------------------------------------------------
local function update_guis(update_orders)
	for _, player in pairs(game.players) do
		update_gui(player,update_orders)
	end
end

--------------------------------------------------------------------------------------
local function close_guis()
	for _, player in pairs(game.players) do
		if player.connected then
			local player_mem = global.player_mem[player.index]
			build_menu_gen(player,player_mem,false)
			build_menu_trader(player,player_mem,false)
			build_menu_objects(player,false)
		end
	end
end

--------------------------------------------------------------------------------------
local function init_tax_rates()
	global.tax_rates = {}
	
	for _, period in ipairs(periods) do
		if tax_enabled == true then
			if period == 0 then
				global.tax_rates[period] = tax_immediate -- tax for immediate action
			else
				global.tax_rates[period] = math.floor(0.5+tax_start * ((24/period) ^ tax_growth))
			end
		else global.tax_rates[period] = 0 end
	end
	
	for period,tax in pairs(global.tax_rates) do
		debug_print( "tax ", period, "h = ", tax, "%" )
	end
end

--------------------------------------------------------------------------------------
local function update_tech_cost(tech)
	local cost = 0
	
	cost = cost + #tech.research_unit_ingredients * tech.research_unit_count * tech_ingr_cost
	cost = cost + tech.research_unit_energy * energy_cost
	
	global.techs_costs[tech.name] = cost
	
	for _, effect in pairs(tech.effects) do
		if effect.type == "unlock-recipe" then
			global.recipes_tech[effect.recipe] = tech.name
		end
	end
end

--------------------------------------------------------------------------------------
local function update_techs_costs()
	global.techs_costs = {}
	global.recipes_tech = {}
	
	for name, tech in pairs(game.forces.player.technologies) do
		update_tech_cost(tech)
	end
end

--------------------------------------------------------------------------------------
local function list_techs_costs()
	debug_print("--------------------------------------------------------------------------------------")
	debug_print("list_techs_costs")
	
	for name, cost in pairs(global.techs_costs) do
		debug_print("tech ", name, " = ", cost)
	end
end

--------------------------------------------------------------------------------------
local function update_objects_prices_start()
	if global.prices_computed then return end
	
	global.prices_computed = true
	debug_print( "update_objects_prices_start" )
	
	global.old_prices = global.prices or {} -- to memorize old prices, and restore dynamics later
	
	global.prices = {}
	global.orig_resources = {}
	global.new_resources = {}
	global.free_products = {}
	global.unknowns = {}
	
	local orig_resources = {}
	local specials = {}
	local free_products = {}
	local regular_products = {}
	
	local recipes = game.forces.player.recipes
		
	-- energy 
	
	global.prices[energy_name] = {overall=energy_price, tech=0, ingrs=0, energy=0}
	
	-- vanilla resources
	
	for name, price in pairs(vanilla_resources_prices) do
		global.prices[name] = {overall=price, tech=0, ingrs=0, energy=0}
		orig_resources[name] = true
	end

	-- special objects

	for name, price in pairs(special_prices) do
		global.prices[name] = {overall=price, tech=0, ingrs=0, energy=0}
		specials[name] = true
	end

	-- additional resources
	
	for name, ent in pairs(game.entity_prototypes) do -- raw resources, TODO: this needs some looking at
		if ent.type == "resource" then 
			local min_prop = ent.mineable_properties
			if min_prop.minable and min_prop.products then -- if this object is minable give it the raw ore price
				for _, prod in pairs(min_prop.products) do
					if global.prices[prod.name] == nil then
						global.prices[prod.name] = {overall=resource_price, tech=0, ingrs=0, energy=0}
						orig_resources[prod.name] = true
					end
				end
			end
		end
	end
	
	-- mark potential undeclared new resources (that are ingredients but never produced)
	
	local new_resources = {}
	
	for _, recipe in pairs(recipes) do
		if recipe.ingredients ~= nil then
			for _, ingr in pairs(recipe.ingredients) do
				if global.prices[ingr.name] == nil and regular_products[ingr.name] == nil and free_products[ingr.name] == nil then
					new_resources[ingr.name] = true -- mark as possible resource
				end
			end
		end
	end
	
	regular_products = nil

	global.orig_resources = orig_resources
	global.specials = specials
	global.new_resources = new_resources
	global.free_products = free_products
end

local function compute_recipe_purity(recipe_name, item_name)
	local recipe = game.forces.player.recipes[recipe_name]

	local other_amount = 0 -- the other stuff that the recipe produces
	local ingredient_amount = 0 -- the stuff we are actually trying to solve for

	table.for_each(recipe.products, function(product)
		-- here we catogorize each of the recipes products into product or other
		if product.name == item_name then
			if product.amount ~= nil then
				ingredient_amount = ingredient_amount + product.amount
			elseif product.amount_min and product.amount_max and product.probability then
				ingredient_amount = ingredient_amount + (product.amount_min + product.amount_max) /2 * product.probability
			end
		elseif product.amount ~= nil then -- if its an other we still need to check if its a probability or an amount
			other_amount = other_amount + product.amount
		elseif product.amount_min and product.amount_max and product.probability then
			other_amount = other_amount + (product.amount_min + product.amount_max) /2 * product.probability
		end
	end)

	-- cant divide by 0
	if other_amount == 0 then other_amount = 1 end
	
	-- if this is the new best recipe then store it
	local purity = ingredient_amount/other_amount

	return purity
end

local function compute_item_cost(item_name, loops, recipes_used)
	if loops == nil then loops = 0 end -- my lazy solution to avoid endless recursion
	if recipes_used == nil then recipes_used = {} end -- same as above
	loops = loops + 1

	-- if this is an uncraftable item then we just assume its a raw/unknown
	if global.item_recipes[item_name] == nil or loops > recipe_depth_maximum then global.prices[item_name] = {overall = unknown_price, tech = 0, ingrs = 0, energy = 0} return global.prices[item_name] end
	
	-- grab the item's recipe
	local recipe_name = global.item_recipes[item_name].recipe
	local recipe = game.forces.player.recipes[recipe_name]

	for _, recipe_used in pairs(recipes_used) do if recipe_used == recipe_name then 
		global.prices[item_name] = {overall = unknown_price, tech = 0, ingrs = 0, energy = 0} return global.prices[item_name] end end
	recipes_used[#recipes_used+1] = recipe_name

	-- iterate thru ingredients and make sure they have a set cost
	for _, ingredient in pairs(recipe.ingredients) do
		if global.prices[ingredient.name] ~= nil then -- do we know the price already?
			ingredient_cost = global.prices[ingredient.name].overall
			
		elseif global.item_recipes[ingredient.name] ~= nil and global.item_recipes[ingredient.name].recipe ~= nil then -- if not and we have a recipe for the ingredient then loop through and calculate it based on ingredients
			compute_item_cost(ingredient.name, loops, recipes_used)

		else -- unknown raw mats
			global.prices[item_name] = {
				overall = unknown_price, -- this should really only happen if a mod introduces a new raw mat,
				tech = 0,
				ingrs = 0,
				energy = 0
			}
		end
	end

	-- okay we now know that the price of the igrs are in the prices table, so now we can just add em up
	local ingredients_cost = 0
	for _, ingredient in pairs(recipe.ingredients) do
		if global.prices[ingredient.name] == nil then compute_item_cost(ingredient.name, loops, recipes_used) end
		ingredients_cost = ingredients_cost + ingredient.amount * global.prices[ingredient.name].overall
	end

	-- compute tech cost
	local tech_cost = 0
	local tech_name = global.recipes_tech[recipe.name]
	if tech_name then
		if global.techs_costs[tech_name] then
			tech_cost = global.techs_costs[tech_name] * tech_amortization
		end
	end

	-- count the amount of product we are making in this recipe
	local product_amount = 0
	for _, product in pairs(recipe.products) do
		if product.name == item_name then
			if product.amount then
				product_amount = product.amount
			elseif product.amount_min and product.amount_max and product.probability then
				product_amount = (product.amount_min + product.amount_max) /2 * product.probability
			end
		end
	end

	-- calculate energy cost
	local energy_cost = recipe.energy * energy_cost

	-- enter cost of ingredient
	if ingredient_amount == 0 then
		global.prices[item_name] = { -- sometimes, probability can be 0, leading to total amount = 0
			overall = unknown_price,
			tech = 0,
			ingrs = 0,
			energy = 0
		}
	else
		local tech_total = math.floor(tech_cost)
		local ingrs_total = math.floor(ingredients_cost / product_amount+0.5)
		local energy_total = math.floor(energy_cost / product_amount+0.5)
		price = (tech_total + ingrs_total + energy_total) * (1+commercial_margin)
		global.prices[item_name] = {
			overall = math.floor(price),
			tech = tech_total,
			ingrs = ingrs_total,
			energy = energy_total
		}
	end
	return (global.prices[item_name])
end

--------------------------------------------------------------------------------------
local function update_objects_prices()

	-- item_recipes looks like {..., item_name = {name, recipe_name}}

	--  this links items (products) to their recipe(s)
	for _, recipe in pairs(game.forces.player.recipes) do
		for _, product in pairs(recipe.products) do

			if game.forces.player.recipes[product.name] ~= nil then -- if we can find a direct recipe match for the item then we dont need to do fancy match
				item_recipe = {name = product.name, recipe = product.name}
			else -- recipe matching, the filters avoid recipes that cause issues for the cost computer
				item_recipe = global.item_recipes[product.name] or {name = product.name, recipe = nil}
				-- item_recipe is the most pure recipe for product

				if item_recipe.recipe ~= nil then 
					local old_purity = compute_recipe_purity(item_recipe.recipe, product.name)
					
					local new_purity = compute_recipe_purity(recipe.name, product.name)

					-- recipe filters here, the recipes we dont want

					-- such as fluid barreling recipes
					local isBarrel = false
					if string.match(recipe.name, "barrel") and not string.match(product.name, "barrel") then
						isBarrel = true end

					-- or recipes with catylists
					local hasCatylist = false
					table.for_each(game.forces.player.recipes[recipe.name].products, function(product)
						-- if the recipe just straight up tells us
						if product.catalyst_amount ~= nil and product.catalyst_amount > 0 then hasCatylist = true
						-- otherwise check for name matches
						else table.for_each(game.forces.player.recipes[recipe.name].ingredients, function(ingr) if ingr.name == product.name then hasCatylist = true end end)
						end
					end)

					if new_purity > old_purity and isBarrel == false and hasCatylist == false then item_recipe.recipe = recipe.name end -- our new king passed our filters!
				else item_recipe.recipe = recipe.name end -- if there is no prexisting recipe our new one is king
			end
			
			global.item_recipes[product.name] = item_recipe
		end
	end

	for _, item in pairs(global.item_recipes) do
		if global.prices[item.name] == nil or global.prices[item.name].overall == nil then compute_item_cost(item.name) end
	end

	-- init dynamic prices for new prices, and restore old dynamics if exists, and filter errors for bad recipes
	
	for name_object, price in pairs(global.prices) do
		local old_price = global.old_prices[name_object]

		-- filters for all the bad values that escaped
		if price.overall == nil then price.overall = unknown_price end
		if price.overall == math.huge then price.overall = unknown_price end

		-- actuall dynamic stuff
		if old_price then
			price.dynamic = old_price.dynamic or 1
			price.previous = old_price.previous or price.overall
			price.evolution = old_price.evolution or 0
		else
			price.dynamic = 1
			price.previous = price.overall or unknown_price
			price.evolution = 0
		end
		
		price.current = price.overall * price.dynamic
	end

	global.old_prices = nil
	global.prices_computed = false

	-- if only_researched_items is on then remove all that arent researched
	if only_items_researched then
		for name, object in pairs(global.prices) do
			recipe = global.item_recipes[name] or nil
			if recipe ~= nil and game.forces.player.recipes[recipe.recipe].enabled == false then
				global.prices[name] = nil end
		end
	end

	return true
end

local function multiply_prices()
	if not (settings.global["BM2-price_multiplyer"] == nil or settings.global["BM2-price_multiplyer"].value == 1) then -- no point of multiplying prices if its just by 1 or not configured at all
		table.for_each(global.prices, function(price) price.current = price.current * settings.global["BM2-price_multiplyer"].value end)
	end
end

--------------------------------------------------------------------------------------
local function update_dynamic_prices()
	if global.prices_computed then return end
	if not dynamic_prices_enabled then return end
	-- update dynamic prices (once per day)
	
	for _, price in pairs(global.prices) do
		
		-- keep in range
		if price.dynamic > dynamic_maximal then
			price.dynamic = dynamic_maximal
		elseif price.dynamic < dynamic_minimal then
			price.dynamic = dynamic_minimal
		end
		
		-- compute current price
		price.current = price.overall * price.dynamic
		
		-- compute price evolution (without slow return)
		price.evolution = price.current - price.previous
		price.previous = price.current

		if price.evolution == 0 then
			-- return slowly to optimal price
			if price.dynamic < 1 then
				price.dynamic = math.min(price.dynamic + dynamic_regrowth,1)
			elseif price.dynamic > 1 then
				price.dynamic = math.max(price.dynamic - dynamic_regrowth,1)
			end
			
			price.current = price.overall * price.dynamic
			price.previous = price.current
		end
	end
end

--------------------------------------------------------------------------------------
local function list_prices()
	if global.prices_computed then return end
	
	debug_print("--------------------------------------------------------------------------------------")
	debug_print("list_prices")
	
	for name, price in pairs(global.prices) do
		local recipe_name = name
		if recipe_name then
			debug_print("price ", name, "=", price.overall, "=", price.tech, "+", price.ingrs, "+", price.energy, " recipe=", recipe_name)
		else
			debug_print("price ", name, "=", price.overall, "=", price.tech, "+", price.ingrs, "+", price.energy, " recipe=NONE")
		end
	end

	debug_print("--------------------------------------------------------------------------------------")
	
	for name, object in pairs(game.item_prototypes) do
		local price = global.prices[name]
		if price == nil then
			debug_print("item ", name, "=NONE")
		else
			debug_print("item ", name, "=", price.overall, "=", price.tech, "+", price.ingrs, "+", price.energy)
		end
	end
	
	for name, object in pairs(game.fluid_prototypes) do
		local price = global.prices[name]
		if price == nil then
			debug_print("fluid ", name, "=NONE")
		else
			debug_print("fluid ", name, "=", price.overall, "=", price.tech, "+", price.ingrs, "+", price.energy)
		end
	end
end

--------------------------------------------------------------------------------------
local function export_prices()
	-- debug_print("export_prices")
	
	game.remove_path(prices_file)

	local s = "object;recipe;techno;total price;tech cost;ingredients cost;energy cost;current;evolution" .. "\n"
	
	if pcall(game.write_file,prices_file,s,true) then
		for name, price in pairs(global.prices) do
			local recipe_name = name
			
			if recipe_name then
				local tech_name = global.recipes_tech[recipe_name]
				if recipe_name == name then recipe_name = "idem" end
				if tech_name == nil then tech_name = "" end
				s = name .. ";" .. recipe_name .. ";" .. tech_name .. ";" 
					.. price.overall .. ";" .. price.tech .. ";" .. price.ingrs .. ";" .. price.energy .. ";" .. 0.1*math.floor(10*price.current) .. ";" .. 0.1*math.floor(10*price.evolution) .. "\n"
			else
				s = name .. ";...;;" 
					.. price.overall .. ";" .. price.tech .. ";" .. price.ingrs .. ";" .. price.energy .. ";" .. 0.1*math.floor(10*price.current) .. ";" .. 0.1*math.floor(10*price.evolution) .. "\n"
			end
			game.write_file('BM2/e.txt',s,true)
		end
	end
end

--------------------------------------------------------------------------------------
local function update_groups()
	-- debug_print("--------------------------------------------------------------------------------------")
	-- debug_print("update_groups")
	
	-- to be run after prices list end !
	
	local groups = {}
	
	for name, object in pairs(game.item_prototypes) do
		if global.prices[name] ~= nil and not object.has_flag("hidden") then
			local group_name = object.group.name
			if groups[group_name] == nil then 
				groups[group_name] = { group = object.group, item = true, fluid = false }
			end
		end
	end
	
	for name, object in pairs(game.fluid_prototypes) do
		if  global.prices[name] ~= nil then
			local group_name = object.group.name
			if groups[group_name] == nil then 
				groups[group_name] = { group = object.group, item = false, fluid = true }
			else
				groups[group_name].fluid = true
			end
		end
	end

	if global.player_mem then
		for _, player in pairs(game.players) do
			local player_mem = global.player_mem[player.index]
			if player_mem then
				player_mem.group_sel_name = nil
				player_mem.object_sel_name = nil
				player_mem.ask_sel = nil
			end
		end
	end
	
	global.groups = groups
end

--------------------------------------------------------------------------------------
local function list_groups()
	debug_print("--------------------------------------------------------------------------------------")
	debug_print("list_groups")
	
	for name, group in pairs(global.groups) do
		debug_print("group:", name, " childs=", #group.group.subgroups)
		for _, subgroup in pairs(group.group.subgroups) do
			debug_print("-> subgroup:", subgroup.name)
		end
	end
end

--------------------------------------------------------------------------------------
local function list_recipes()
	debug_print("--------------------------------------------------------------------------------------")
	debug_print("list_recipes")
	
	for name, recipe in pairs(game.forces.player.recipes) do
		debug_print("recipe:", name, " hidden=", recipe.hidden)
	end
end

--------------------------------------------------------------------------------------
local function get_hour()
	-- refresh hour and detect hour change ; hour increases continuously, and does not reset at 24.
	local surf = game.surfaces.nauvis

	if surf.always_day ~= global.always_day then
		global.always_day = surf.always_day
		global.hour_prev = -1
	end
		
	if surf.always_day then
		global.hour = math.floor(game.tick * 24 / 25000) -- one day is 25000 ticks, game starts at noon
		if global.hour ~= global.hour_prev then
			if global.hour%24 == 0 then -- noon
				global.day = global.day + 1
				global.day_changed = true
			end
			global.hour_changed = 4
			global.hour_prev = global.hour
		end
	else
		local hour = math.floor(surf.daytime * 24) -- daytime [0,1], noon = 0.0, midnight = 0.5
		if hour ~= global.hour_prev then
			if hour == 0 then -- noon
				global.day = global.day + 1
				global.day_changed = true
			end
			global.hour = 24*global.day + hour
			global.hour_changed = 4
			global.hour_prev = hour
		end
	end
end

--------------------------------------------------------------------------------------
local function compute_force_data(force_mem)
	local tot_taxes = force_mem.sales_taxes + force_mem.purchases_taxes
	local tot = force_mem.sales + force_mem.purchases + tot_taxes
	if tot == 0 or tax_enabled == false then
		force_mem.tax_rate = 0
	else
		force_mem.tax_rate = math.floor(0.5+tot_taxes * 100 / tot)
	end
end

--------------------------------------------------------------------------------------
local function init_trader( trader, level )
	trader.auto = default_auto -- automatic trading
	trader.daylight = false -- trades only during daylight (for selling accumulators)
	trader.n_period=default_n_period
	trader.period=periods[default_n_period]
	
	trader.evaluation = 0 -- gross value of trader content
	
	trader.money_tot = 0 -- total sales or incomes
	trader.taxes_tot = 0 -- total taxes
	trader.tax_rate_tot = 0 -- total average tax rate
	
	trader.hour = global.hour -- hour of counter reset (initialized with last hour tick)
	trader.dhour = 0 -- hours since last reset
	trader.money_reset = 0 -- money at counter reset
	trader.taxes_reset = 0 -- taxes at counter reset
	trader.money = 0 -- sales or incomes since counter reset
	trader.taxes = 0 -- taxes or incomes since counter reset
	trader.tax_rate = 0 -- average tax rate
	trader.money_average = 0 -- money per day since counter reset
	
	trader.hour_period = global.hour -- starting hour of last period (used by counter reset)
	trader.money_tot_start_period = 0 -- money at beginning of last period
	trader.money_period = 0 -- money on last period
	
	trader.orders_tot = 0 -- total of the purchase list, without taxes
	trader.orders = {} -- purchase orders, list of {name, count}
	trader.sold_name = nil -- name of the last sold item
	-- trader.price = nil -- price of the main object sold (1 item, fuild or energy)
	
	trader.editer = nil -- player who is currently editing
	
	if level ~= nil then
		trader.level = level
		
		if level == 1 then trader.tank_max = 25000 end
		if level == 2 then trader.tank_max = 100000 end
		if level == 3 then trader.tank_max = 200000 end
		if level == 4 then trader.tank_max = 400000 end
		
		if level == 1 then trader.accu_max = 10 end
		if level == 2 then trader.accu_max = 100 end
		if level == 3 then trader.accu_max = 250 end
		if level == 4 then trader.accu_max = 500 end
	end
end

--------------------------------------------------------------------------------------
local function copy_trader( trader1, trader2 )
	trader2.auto = trader1.auto
	trader2.daylight = trader1.daylight
	trader2.n_period=trader1.n_period
	trader2.period=trader1.period
	
	if (not trader1.sell_or_buy) and (not trader2.sell_or_buy) and trader1.type == trader2.type then
		trader2.orders = {}
	
		for name, order in pairs(trader1.orders) do
			table.insert(trader2.orders,order)
		end
	end
end

--------------------------------------------------------------------------------------
local function evaluate_trader(trader)
	if global.prices_computed then return end
	
	if trader.entity == nil or not trader.entity.valid then 
		trader.evaluation = 0
		return
	end
	
	local money = 0
	
	if trader.type == trader_type.item then
		local inv = trader.entity.get_inventory(defines.inventory.chest)
		local contents = inv.get_contents()
		local price = nil
		
		for name, count in pairs(inv.get_contents()) do
			price = global.prices[name]
			if price ~= nil then
				money = money + count * price.current 
			end
		end
		
	elseif trader.type == trader_type.fluid then
		local tank = trader.entity
		if tank.fluidbox then
			local box = tank.fluidbox[1]
			if box ~= nil then
				local name = box.name
				local count = box.amount
			
				local price = global.prices[name]
				if price ~= nil then
					money = count * price.current 
				end
			end
		end
		
	elseif trader.type == trader_type.energy then
		local accu = trader.entity
		local name = energy_name
		local count = accu.energy / 1000000
		local price = global.prices[name]
		if price ~= nil then
			money = count * price.current 
		end
	end
	
	trader.evaluation = money
end

--------------------------------------------------------------------------------------
local function update_transaction(force_mem,type,name,price,count)
	
	-- save the transaction
	if force_mem.transactions[name] == nil then
		force_mem.transactions[name] = {count=0,type=type}
		force_mem.new_transaction = true
	end
	force_mem.transactions[name].count = force_mem.transactions[name].count + count
	
	-- calculate the dynamic of the price
	if name ~= "ucoin" and dynamic_prices_enabled then
		if type == "item" and dynamic_influence_item ~= 0 then
			price.dynamic = price.dynamic + count * dynamic_influence_item
		elseif type == "fluid" and dynamic_influence_fluid ~= 0 then
			price.dynamic = price.dynamic + count * dynamic_influence_fluid
		elseif dynamic_influence_energy ~= 0 then
			price.dynamic = price.dynamic + count * dynamic_influence_energy
		end
		
		-- keep the dynamic in range
		if price.dynamic > dynamic_maximal then
			price.dynamic = dynamic_maximal
		elseif price.dynamic < dynamic_minimal then
			price.dynamic = dynamic_minimal
		end
	end
end

--------------------------------------------------------------------------------------
local function sell_trader(trader,force_mem,tax_rate)
	if global.prices_computed then return(nil) end
	
	if trader.entity == nil or not trader.entity.valid then return(nil) end
	
	if tax_rate == nil then tax_rate = global.tax_rates[trader.period] end
	if tax_enabled == false then tax_rate = 0 end
	
	local money1, tax1
	local money = 0
	local taxes = 0

	if trader.type == trader_type.item then
		local inv = trader.entity.get_inventory(defines.inventory.chest)
		local contents = inv.get_contents()
		local price = nil
		
		for name, count in pairs(inv.get_contents()) do
			price = global.prices[name]
			
			if price ~= nil then
				money1 = count * price.current 
				
				if name == "ucoin" then
					tax1 = 0
				else
					tax1 = money1 * tax_rate / 100
				end
				money = money + money1 
				taxes = taxes + tax1
				
				inv.remove({name=name,count=count})
				
				update_transaction(force_mem,"item",name,price,-count)
				if count ~= 0 then 
					trader.sold_name = name
				end
			end
		end
		
		
	elseif trader.type == trader_type.fluid then
		local tank = trader.entity
		if tank.fluidbox then
			local box = tank.fluidbox[1]
			if box ~= nil then
				local name = box.name
				local count = box.amount
				local price = global.prices[name]
				
				if price ~= nil then
					money1 = count * price.current 
					tax1 = money1 * tax_rate / 100
					money = money + money1 
					taxes = taxes + tax1
					
					tank.fluidbox[1] = nil
					
					update_transaction(force_mem,"fluid",name,price,-count)
					if count ~= 0 then 
						trader.sold_name = name
					end
				end
			end
		end
		
	elseif trader.type == trader_type.energy then
		local accu = trader.entity
		local name = energy_name
		local count = accu.energy / 1000000
		local price = global.prices[energy_name]
		
		if price ~= nil then
			money1 = count * price.current 
			tax1 = money1 * tax_rate / 100
			money = money + money1
			taxes = taxes + tax1
			
			accu.energy = 0
			
			update_transaction(force_mem,"energy",name,price,-count)
			trader.sold_name = name
		end
	end

	trader.money_tot = trader.money_tot + money
	trader.taxes_tot = trader.taxes_tot + taxes
	
	force_mem.credits = force_mem.credits + money - taxes
	force_mem.sales = force_mem.sales + money
	force_mem.sales_taxes = force_mem.sales_taxes + taxes

	return(money)
end

--------------------------------------------------------------------------------------
local function buy_trader(trader,force_mem,tax_rate)
	if global.prices_computed then return(nil) end
	
	if trader.entity == nil or not trader.entity.valid then return(nil) end
	
	if tax_rate == nil then	tax_rate = global.tax_rates[trader.period] end
	if tax_enabled == false then tax_rate = 0 end

	local money1
	local tax1
	local money = 0
	local taxes = 0
	
	if trader.type == trader_type.item then
		local inv = trader.entity.get_inventory(defines.inventory.chest)
		local price = nil
		
		for i=1,#trader.orders do
			local order = trader.orders[i]
			local name = order.name
			local count = order.count
			price = global.prices[name]
			
			if price and count > 0 then
				money1 = count * price.current 
				
				if name == "ucoin" then
					tax1 = 0
				else
					tax1 = money1 * tax_rate / 100
				end
				
				if money1+tax1 <= force_mem.credits then
					-- can buy !
					local purchased = inv.insert({name=name,count=count})
					if purchased < count then
						money1 = purchased * price.current 
						if name == "ucoin" then
							tax1 = 0
						else
							tax1 = money1 * tax_rate / 100
						end
					end
					force_mem.credits = force_mem.credits - money1 - tax1
					money = money + money1
					taxes = taxes + tax1
					
					update_transaction(force_mem,"item",name,price,purchased)
				end
			end			
		end
		
	elseif trader.type == trader_type.fluid then
		local order = trader.orders[1]
		local tank = trader.entity
		
		if order and tank.fluidbox then
			local name = order.name
			local price = global.prices[name]
			local box = tank.fluidbox[1]
			local name_box = name
			local amount_box = 0
			
			if box == nil then
				box = {name = name_box, amount = amount_box }
			else
				name_box = box.name
				amount_box = box.amount
			end
			
			if name_box ~= name and amount_box < 0.1 then
				name_box = name
				amount_box = 0
				box = {name = name_box, amount = amount_box }
			end
			
			if name_box == name and price then
				local purchased = math.min(order.count,(trader.tank_max - amount_box))
				money = purchased * price.current 
				
				if purchased > 0 and money <= force_mem.credits then
					taxes = money * tax_rate / 100
					money = money - taxes
					force_mem.credits = force_mem.credits - money - taxes
				
					box.amount = box.amount + purchased
					tank.fluidbox[1] = box
				
					update_transaction(force_mem,"fluid",name,price,purchased)
				end
			end
		end
		
	elseif trader.type == trader_type.energy then
		local order = trader.orders[1]
		local accu = trader.entity
		local name = energy_name
		local count = accu.energy / 1000000
		local price = global.prices[name]
		
		if order and price then
			local purchased = math.min(order.count,trader.accu_max - count)
			money = purchased * price.current
			
			if purchased > 0 and money <= force_mem.credits then
				taxes = money * tax_rate / 100
				money = money - taxes
				force_mem.credits = force_mem.credits - money - taxes
			
				accu.energy = accu.energy + purchased * 1000000
			
				update_transaction(force_mem,"energy",name,price,purchased)
			end
		end
	end
	
	trader.money_tot = trader.money_tot + money
	trader.taxes_tot = trader.taxes_tot + taxes
	
	force_mem.purchases = force_mem.purchases + money
	force_mem.purchases_taxes = force_mem.purchases_taxes + taxes

	return(money)
end

--------------------------------------------------------------------------------------
local function listen_trader(trader)
	local ent = trader.entity
	if ent == nil or not ent.valid then return(false) end
	local changed = false
	
	local network = ent.get_circuit_network(defines.wire_type.red)
	
	if network == nil then 
		network = ent.get_circuit_network(defines.wire_type.green)
	end
	
	if network == nil then return(false) end
	
	local function listen_signal(signal)
		local val = network.get_signal(signal)
		-- debug_print( "auto=", val )
		if val ~= 0 then
			local auto = (val ~= 1)
			if auto ~= trader.auto then changed = true end
			trader.auto = auto
		end
	end
	
	listen_signal(trader_signals.auto_all)
	
	if trader.sell_or_buy then
		listen_signal(trader_signals.auto_sell)
	else
		listen_signal(trader_signals.auto_buy)
	end
	
	if trader.editer and changed then update_menu_trader(trader.editer,nil,false) end
	
	return(true)
end

--------------------------------------------------------------------------------------
local function listen_traders(force_mem)
	if global.prices_computed then return(nil) end
	
	for i=1,#force_mem.traders_buy do
		local trader = force_mem.traders_buy[i]
		listen_trader(trader)
	end
	
	for i=1,#force_mem.traders_sell do
		local trader = force_mem.traders_sell[i]
		listen_trader(trader)
	end
end

-- params = {parameters={
	-- {index=1,signal={type="virtual",name="signal-clock-gametick"},count=math.floor(game.tick)},
	-- {index=2,signal={type="virtual",name="signal-clock-day"},count=global.day},
	-- {index=3,signal={type="virtual",name="signal-clock-hour"},count=global.h},
	-- {index=4,signal={type="virtual",name="signal-clock-minute"},count=global.m},
	-- {index=5,signal={type="virtual",name="signal-clock-alwaysday"},count=iif(global.surface.always_day,1,0)},
	-- {index=6,signal={type="virtual",name="signal-clock-darkness"},count=math.floor(global.surface.darkness*100)},
	-- {index=7,signal={type="virtual",name="signal-clock-lightness"},count=math.floor((1-global.surface.darkness)*100)},
-- }}

-- clock.entity.get_control_behavior().parameters = params

--------------------------------------------------------------------------------------
local function find_trader_sell(force_mem,ent)
	for _, trader in pairs(force_mem.traders_sell) do
		if trader.entity == ent then
			 return(trader)
		end
	end
	
	return(nil)
end

--------------------------------------------------------------------------------------
local function find_trader_buy(force_mem,ent)
	for _, trader in pairs(force_mem.traders_buy) do
		if trader.entity == ent then
			 return(trader)
		end
	end
	
	return(nil)
end

--------------------------------------------------------------------------------------
local function compute_trader_data(trader,update_orders)
	if global.prices_computed then return end
	
	local tot
	
	if trader.sell_or_buy then
		tot = trader.money_tot -- + trader.taxes_tot 
	else
		tot = trader.money_tot 
	end
	
	if tot == 0 then
		trader.tax_rate_tot = 0
	else
		trader.tax_rate_tot = math.floor(0.5+100 * trader.taxes_tot  / tot)
	end

	trader.money = trader.money_tot - trader.money_reset
	trader.taxes = trader.taxes_tot - trader.taxes_reset
	
	trader.dhour = global.hour - trader.hour
	if trader.dhour == 0 then
		trader.money_average = 0
	else
		trader.money_average = math.floor(0.5+trader.money * 24 / trader.dhour)
	end
	
	if trader.sell_or_buy then
		tot = trader.money -- + trader.taxes
	else
		tot = trader.money
	end
	
	if tot == 0 then
		trader.tax_rate = 0
	else
		trader.tax_rate = math.floor(0.5+100 * trader.taxes  / tot)
	end

	if trader.sell_or_buy then
	else
		tot = 0
		for _, order in pairs(trader.orders) do
			local price = global.prices[order.name]
			if price then
				tot = tot + order.count * price.current
			end
		end
		
		trader.orders_tot = tot
		-- debug_print(tot)
	end
	
	if update_orders ~= nil and trader.editer then update_menu_trader(trader.editer,nil,update_orders) end
end

--------------------------------------------------------------------------------------
local function clean_orders_and_transactions()
	for name, force in pairs(game.forces) do
		debug_print("name=" .. name)
		
		local force_mem = global.force_mem[name]
		
		-- clean orders with non existing objects
	
		for i=#force_mem.traders_buy,1,-1 do
			local trader = force_mem.traders_buy[i]
			if trader.type == trader_type.item then
				for i=#trader.orders,1,-1 do
					local order = trader.orders[i]
					if game.item_prototypes[order.name] == nil or i > 99 then
						table.remove(trader.orders,i)
					end
				end
			elseif trader.type == trader_type.fluid then
				for i=#trader.orders,1,-1 do
					local order = trader.orders[i]
					if game.fluid_prototypes[order.name] == nil or i > 99 then
						table.remove(trader.orders,i)
					end
				end
			end
		end
		
		-- clean transactions with non existing objects
	
		for name_transaction, transaction in pairs(force_mem.transactions) do
			if transaction.type == "item" then
				if game.item_prototypes[name_transaction] == nil then
					force_mem.transactions[name_transaction] = nil
				end
			elseif transaction.type == "fluid" then
				if game.fluid_prototypes[name_transaction] == nil then
					force_mem.transactions[name_transaction] = nil
				end
			end
		end
	end
end

--------------------------------------------------------------------------------------
local function init_globals()
	-- initialize or update general globals of the mod
	debug_print( "init_globals" )
	
	global.tick = global.tick or 0
	global.force_mem = global.force_mem or {}
	global.player_mem = global.player_mem or {}
	
	global.always_day = game.surfaces.nauvis.always_day
	global.day = global.day or 0 -- day (changes at noon)
	global.day_changed = false
	global.hour = global.hour or -1 -- hour (always increases, does not reset at 24...)
	global.hour_prev = global.hour_prev or -1
	global.hour_changed = 0

	global.item_recipes = {}
	
	if global.prices_computed == nil then global.prices_computed = false end

	if global.techs_costs == nil then -- costs for every tech
		update_techs_costs() 
	end
	
	global.orig_resources = global.orig_resources or {} -- items undeclared as resources
	global.new_resources = global.new_resources or {} -- items that could be undeclared resources (used as ingredients but never produced)
	global.free_products = global.free_products or {} -- items with no prices
	global.unknowns = global.unknowns or {} -- items with no prices
	
	if global.prices == nil then -- prices for every item/fluid
		update_objects_prices_start()
	end
	
	global.groups = global.groups or {}
	
	-- if global.groups == nil then
		-- update_groups()
	-- end
	
	if global.tax_rates == nil then
		init_tax_rates()
	end
end

--------------------------------------------------------------------------------------
local function init_force(force)
	assert(global.force_mem ~= nil)
	
	-- initialize or update per force globals of the mod
	debug_print( "init_force ", force.name )
	
	global.force_mem[force.name] = global.force_mem[force.name] or {}
	local force_mem = global.force_mem[force.name]
	
	if force_mem.pause == nil then force_mem.pause = false end
	force_mem.n_period = force_mem.n_period or default_n_period
	force_mem.period = periods[force_mem.n_period]
	-- force_mem.credits = force_mem.credits or ((debug_status == 1) and 1000000 or 0)
	force_mem.credits = force_mem.credits or 0
	force_mem.credits_startday = force_mem.credits_startday or global.day -- credits at beginning of last day
	force_mem.credits_lastday = force_mem.credits_lastday or 0 -- credits during last day
	force_mem.var_lastday = force_mem.var_lastday or 0 -- variation od credit during last day
	force_mem.sales = force_mem.sales or 0 -- sum of all net sales
	force_mem.sales_taxes = force_mem.sales_taxes or 0 -- sum of all sales taxes
	force_mem.purchases = force_mem.purchases or 0 -- sum of all net purchases
	force_mem.purchases_taxes = force_mem.purchases_taxes or 0 -- sum of all purchases taxes
	force_mem.tax_rate = force_mem.tax_rate or 0 -- average overall tax rate
	force_mem.transactions = force_mem.transactions or {} -- balance per object index by name, {count, type} type = "item", "fluid", "energy"
	
	force_mem.traders_sell = force_mem.traders_sell or {}
	force_mem.traders_buy = force_mem.traders_buy or {}
end

--------------------------------------------------------------------------------------
local function init_forces()
	for _, force in pairs(game.forces) do
		init_force(force)
	end
	
	-- clean_orders_and_transactions()
end

--------------------------------------------------------------------------------------
local function init_player(player)
	if global.player_mem == nil then return end
	
	-- initialize or update per player globals of the mod, and reset the gui
	debug_print( "init_player ", player.name, " connected=", player.connected )
	
	global.player_mem[player.index] = global.player_mem[player.index] or {}
	
	local player_mem = global.player_mem[player.index]
	if player_mem.auto_close == nil then player_mem.auto_close = false end
	player_mem.group_sel_name = player_mem.group_sel_name or nil
	player_mem.object_sel_name = player_mem.object_sel_name or nil
	player_mem.ask_sel = player_mem.ask_sel or nil
	
	player_mem.opened = player_mem.opened or nil
	player_mem.opened_trader = player_mem.opened_trader or nil
	player_mem.order_sel_n = player_mem.order_sel_n or 0 -- currently edited order
	
	player_mem.cursor_name = nil
	
	if player.connected then
		build_bar(player)
		update_bar(player)
	end
end

--------------------------------------------------------------------------------------
local function init_players()
	for _, player in pairs(game.players) do
		init_player(player)
	end
end

--------------------------------------------------------------------------------------
local function on_init()
	-- called once, the first time the mod is loaded on a game (new or existing game)
	gui.init()
	gui.build_lookup_tables()
	init_globals()
	init_forces()
	init_players()
end

script.on_init(on_init)

local function on_load()
	gui.build_lookup_tables()
end
script.on_load(on_load)

--------------------------------------------------------------------------------------
local function on_configuration_changed(data)
	
	-- detect any mod or game version change
	if data.mod_changes ~= nil then
		
		init_globals()
		init_forces()
		init_players()
		init_tax_rates()
		
		local changes = data.mod_changes[debug_mod_name]
		gui.init()
		gui.check_filter_validity()
		
		close_guis()

		-- if any other mod install or uninstall, rescan prices ! and clean orders

		if not global.prices_computed then
			debug_print( "update other mods" )
			update_techs_costs()
			update_objects_prices_start()		
		end

		-- update_groups()

		clean_orders_and_transactions()
	end
end

script.on_configuration_changed(on_configuration_changed)

script.on_event(defines.events.on_runtime_mod_setting_changed, configure_settings)

--------------------------------------------------------------------------------------
local function on_force_created(event)
	-- called at player creation
	local force = event.force
	debug_print( "force created ", force.name )
	
	init_force(force)
end

script.on_event(defines.events.on_force_created, on_force_created )

--------------------------------------------------------------------------------------
local function on_forces_merging(event)
	local force1 = event.source
	local force2 = event.destination
	debug_print( "force merging ", force1.name, " into ", force2.name )
	
	local force_mem1 = global.force_mem[force1.name]
	local force_mem2 = global.force_mem[force2.name]
	
	force_mem2.credits = force_mem2.credits + force_mem1.credits
	force_mem2.credits_startday = force_mem2.credits_startday + force_mem1.credits_startday
	force_mem2.credits_lastday = force_mem2.credits_lastday + force_mem1.credits_lastday
	force_mem2.var_lastday = force_mem2.var_lastday + force_mem1.var_lastday
	force_mem2.sales = force_mem2.sales + force_mem1.sales
	force_mem2.sales_taxes = force_mem2.sales_taxes + force_mem1.sales_taxes
	force_mem2.purchases = force_mem2.purchases + force_mem1.purchases
	force_mem2.purchases_taxes = force_mem2.purchases_taxes + force_mem1.purchases_taxes
	
	concat_lists(force_mem2.traders_sell, force_mem1.traders_sell)
	concat_lists(force_mem2.traders_buy, force_mem1.traders_buy)

	-- global.force_mem[force1.name] = nil

	compute_force_data(force_mem2)
	update_guis_force(force2,true)
end

script.on_event(defines.events.on_forces_merging, on_forces_merging )

--------------------------------------------------------------------------------------
local function on_cutscene_cancelled(event)
	-- called after player creation, when we can access the inventory
	local player = game.players[event.player_index]
	debug_print( "player created ", player.name )
	
	init_player(player)
	
	if debug_status == 1 then
		local inv = player.get_inventory(defines.inventory.character_main)
		inv.insert({name="fast-inserter", count=50})
		inv.insert({name="trader-chst-sel", count=10})
		inv.insert({name="trader-chst-buy", count=10})
		inv.insert({name="trader-tank-sel", count=10})
		inv.insert({name="trader-tank-buy", count=10})
		inv.insert({name="trader-accu-sel", count=10})
		inv.insert({name="trader-accu-buy", count=10})
		inv.insert({name="ucoin", count=100000})
		debug_print("created debug inv")
	end
end

script.on_event(defines.events.on_cutscene_cancelled, on_cutscene_cancelled)

--------------------------------------------------------------------------------------
local function on_player_joined_game(event)
	-- called in SP(once) and MP(at every connect), eventually after on_player_created
	local player = game.players[event.player_index]
	debug_print( "player joined ", player.name )
	
	init_player(player)
end

script.on_event(defines.events.on_player_joined_game, on_player_joined_game )

--------------------------------------------------------------------------------------
local function on_player_cursor_stack_changed(event)
	local player = game.players[event.player_index]
	local player_mem = global.player_mem[player.index]
	
	-- debug_print( "on_player_cursor_stack_changed ", player.name )
	
	if player.cursor_stack and player.cursor_stack.valid_for_read then
		player_mem.cursor_name = player.cursor_stack.name
	else	
		player_mem.cursor_name = nil
	end
	
	update_bar(player)
end

script.on_event(defines.events.on_player_cursor_stack_changed, on_player_cursor_stack_changed )

--------------------------------------------------------------------------------------
local function suffix_to_level(suffix)
	if suffix == "" then
		return(1)
	elseif suffix == "-mk2" then
		return(2)
	elseif suffix == "-mk3" then
		return(3)
	elseif suffix == "-mk4" then
		return(4)
	end
end

--------------------------------------------------------------------------------------
local function on_creation( event )
	local ent = event.created_entity
	local ent_name = ent.name
	local prefix = string.sub(ent_name,1,15)
	local sell_or_buy = nil
	local type = nil
	
	-- debug_print( "creation ", ent_name )
	
	if prefix == "trader-chst-sel" then
		sell_or_buy = true
		type = trader_type.item
	elseif prefix == "trader-chst-buy" then
		sell_or_buy = false
		type = trader_type.item
	elseif prefix == "trader-tank-sel" then
		sell_or_buy = true
		type = trader_type.fluid
	elseif prefix == "trader-tank-buy" then
		sell_or_buy = false
		type = trader_type.fluid
	elseif prefix == "trader-accu-sel" then
		sell_or_buy = true
		type = trader_type.energy
	elseif prefix == "trader-accu-buy" then
		sell_or_buy = false
		type = trader_type.energy
	end
	
	if sell_or_buy ~= nil then
		local suffix = string.sub(ent_name,16,19)
		local level = suffix_to_level(suffix)
		local force_mem = global.force_mem[ent.force.name]
		-- if ent.force.name = 'neutral' then force_mem = global.force_mem['player'] end
		-- this is how you would fix the neutral chest bug, see issue 22, however i cant find
		-- that setting to test it so im not exactly sure whats up
		local trader = { entity=ent, sell_or_buy = sell_or_buy, type = type }
		init_trader(trader,level)
		
		trader.n_period = force_mem.n_period
		trader.period = force_mem.period

		if sell_or_buy then
			table.insert(force_mem.traders_sell,trader)
		else
			if type == trader_type.item then
				trader.orders = {
					{name = "coal", count = 0, price = global.prices["coal"].current },
				}
			elseif type == trader_type.fluid then
				trader.orders = {
					{name = "crude-oil", count = 0, price = global.prices["crude-oil"].current },
				}
			elseif type == trader_type.energy then
				trader.orders = {
					{name = energy_name, count = 0, price = global.prices[energy_name].current },
				}
			end
			table.insert(force_mem.traders_buy,trader)
		end
		
		compute_trader_data(trader)
	end
end

script.on_event(defines.events.on_built_entity, on_creation )
script.on_event(defines.events.on_robot_built_entity, on_creation )

--------------------------------------------------------------------------------------
local function on_destruction( event )
	local ent = event.entity
	local ent_name = ent.name
	local prefix = string.sub(ent_name,1,15)
	
	if prefix == "trader-chst-sel" or prefix == "trader-tank-sel" or prefix == "trader-accu-sel" then
		-- debug_print( "destruction ", ent_name )
		local force_mem = global.force_mem[ent.force.name]
		for i, trader in pairs(force_mem.traders_sell) do
			if trader.entity == ent then
				table.remove(force_mem.traders_sell,i)
				break
			end
		end
		
	elseif prefix == "trader-chst-buy" or prefix == "trader-tank-buy" or prefix == "trader-accu-buy" then
		-- debug_print( "destruction ", ent_name )
		local force_mem = global.force_mem[ent.force.name]
		for i, trader in pairs(force_mem.traders_buy) do
			if trader.entity == ent then
				trader.orders = nil
				table.remove(force_mem.traders_buy,i)
				break
			end
		end
	end
end

script.on_event(defines.events.on_entity_died, on_destruction )
script.on_event(defines.events.on_robot_pre_mined, on_destruction )
script.on_event(defines.events.on_pre_player_mined_item, on_destruction )

--------------------------------------------------------------------------------------
local function on_entity_settings_pasted(event)
	local ent1 = event.source
	local ent2 = event.destination
	local prefix1 = string.sub(ent1.name,1,15)
	local prefix2 = string.sub(ent2.name,1,15)
	local trader1, trader2

	debug_print( "on_entity_settings_pasted src=", ent1.name, " dest=", ent2.name )
	
	if prefix1 == "trader-chst-sel" or prefix1 == "trader-tank-sel" or prefix1 == "trader-accu-sel" then
		local force_mem = global.force_mem[ent1.force.name]
		trader1 = find_trader_sell(force_mem,ent1)
	elseif prefix1 == "trader-chst-buy" or prefix1 == "trader-tank-buy" or prefix1 == "trader-accu-buy" then
		local force_mem = global.force_mem[ent1.force.name]
		trader1 = find_trader_buy(force_mem,ent1)
	end
	
	if prefix2 == "trader-chst-sel" or prefix2 == "trader-tank-sel" or prefix2 == "trader-accu-sel" then
		local force_mem = global.force_mem[ent2.force.name]
		trader2 = find_trader_sell(force_mem,ent2)
	elseif prefix2 == "trader-chst-buy" or prefix2 == "trader-tank-buy" or prefix2 == "trader-accu-buy" then
		local force_mem = global.force_mem[ent2.force.name]
		trader2 = find_trader_buy(force_mem,ent2)
	end
	
	
	if trader1 and trader2 then
		copy_trader(trader1,trader2)
	end
end

script.on_event(defines.events.on_entity_settings_pasted,on_entity_settings_pasted)

-------------------------------------------------------------------------------------
local function on_tick(event)
	if global.tick >= 99 then 
		global.tick = 0
		
	elseif global.tick%20 == 1 then
		-- check hour change
		get_hour()
		
		-- manage prices list build

		if global.prices_computed then
			
			if (update_objects_prices()) then
				-- update_objects_prices_end()
				
				update_groups()
				-- export_uncommons()
				clean_orders_and_transactions()
				update_dynamic_prices()

				close_guis()

				multiply_prices()

				message_all({"blkmkt-gui-rescan-done"})
			end
		end
		
		-- manage opened traders
		for _, player in pairs(game.players) do
			if player.connected then
				local player_mem = global.player_mem[player.index]
				local opened = player.opened
				
				if opened and player.opened_gui_type ~= 5 then
					if opened ~= player_mem.opened then
						if player_mem.opened_trader then
							player_mem.opened_trader.editer = nil
							
							build_menu_trader(player,player_mem,false)
							build_menu_objects(player,false)
						end
						
						local force_mem = global.force_mem[player.force.name]
						local prefix = string.sub(opened.name,1,15)
						
						if prefix == "trader-chst-sel" or prefix == "trader-tank-sel" or prefix == "trader-accu-sel" then
							build_menu_objects(player,false)
							local trader = find_trader_sell(force_mem,opened)
							if trader then
								if trader.editer == nil or not trader.editer.connected then
									player_mem.opened_trader = trader
									trader.editer = player
									build_menu_trader(player,player_mem,true)
									update_menu_trader(player,player_mem,true)
								else
									player.print({"blkmkt-gui-trader-edited",trader.editer.name})
								end
							end
						elseif prefix == "trader-chst-buy" or prefix == "trader-tank-buy" or prefix == "trader-accu-buy" then
							build_menu_objects(player,false)
							local trader = find_trader_buy(force_mem,opened)
							if trader then
								if trader.editer == nil or not trader.editer.connected then
									player_mem.opened_trader = trader
									trader.editer = player
									build_menu_trader(player,player_mem,true)
									update_menu_trader(player,player_mem,true)
								else
									player.print({"blkmkt-gui-trader-edited",trader.editer.name})
								end
							end
						end
						
						player_mem.opened = opened
					end
				else
					if player_mem.opened then
						if player_mem.opened_trader then
							player_mem.opened_trader.editer = nil
							
							build_menu_trader(player,player_mem,false)
							build_menu_objects(player,false)
						end
						
						player_mem.opened = nil
						player_mem.opened_trader = nil
					end
				end
			end
		end
	
	elseif global.tick == 18 then
		-- listen signals
		
		for name, force in pairs(game.forces) do
			local force_mem = global.force_mem[name]
			listen_traders(force_mem)
		end

		-- EVERY HOUR : 
		if not global.prices_computed and global.hour_changed == 4 then
			global.hour_changed = global.hour_changed - 1 
			
		end
		
	elseif global.tick == 38 then
		-- EVERY HOUR : do sales
		
		if not global.prices_computed and global.hour_changed == 3 then
			global.hour_changed = global.hour_changed - 1 
			
			for name, force in pairs(game.forces) do
				local force_mem = global.force_mem[name]
				local money = 0
				-- debug_print("force ", name, " traders=",#force_mem.traders_sell)
				for i=#force_mem.traders_sell,1,-1 do
					local trader = force_mem.traders_sell[i]
					if global.hour % trader.period == 0 then
						trader.hour_period = global.hour
						if trader.auto and not force_mem.pause then
							local ent = trader.entity
							-- if not(trader.daylight and trader.type == trader_type.energy and ent.surface.darkness > 0.5) then
								local money1 = sell_trader(trader,force_mem)
								if money1 == nil then
									table.remove(force_mem.traders_sell,i)
								else
									money = money + money1
								end
							-- end
						end
					end
				end
				-- if money ~= 0 then
					-- update_bars(force)
				-- end
			end
		end
		
	elseif global.tick == 58 then
		-- EVERY HOUR : do purchases
		
		if not global.prices_computed and global.hour_changed == 2 then
			global.hour_changed = global.hour_changed - 1 
			
			for name, force in pairs(game.forces) do
				local force_mem = global.force_mem[name]
				local money = 0
				-- debug_print("force ", name, " traders=",#force_mem.traders_buy)
				for i=#force_mem.traders_buy,1,-1 do
					local trader = force_mem.traders_buy[i]
					if global.hour % trader.period == 0 then
						trader.hour_period = global.hour
						if trader.auto and not force_mem.pause then
							local money1 = buy_trader(trader,force_mem)
							if money1 == nil then
								table.remove(force_mem.traders_buy,i)
							else
								money = money + money1
							end
						end
					end
				end
				-- if money ~= 0 then
					-- update_bars(force)
				-- end
			end
		end
		
	elseif global.tick == 78 then
		if not global.prices_computed and global.hour_changed == 1 then
			global.hour_changed = global.hour_changed - 1 
			
			-- EVERY HOUR : compute period averages
		
			for name, force in pairs(game.forces) do
				local force_mem = global.force_mem[name]
				
				for i=#force_mem.traders_sell,1,-1 do
					local trader = force_mem.traders_sell[i]
					if trader.auto and (not force_mem.pause) and global.hour % trader.period == 0 then
						compute_trader_data(trader)
						trader.money_period = trader.money_tot - trader.money_tot_start_period
						-- debug_print(trader.money_tot_start_period, " -> ", trader.money_tot, " = ", trader.money_period)
						trader.money_tot_start_period = trader.money_tot 
					end
				end
				
				for i=#force_mem.traders_buy,1,-1 do
					local trader = force_mem.traders_buy[i]
					if trader.auto and (not force_mem.pause) and global.hour % trader.period == 0 then
						compute_trader_data(trader)
						trader.money_period = trader.money_tot - trader.money_tot_start_period
						-- debug_print(trader.money_tot_start_period, " -> ", trader.money_tot, " = ", trader.money_period)
						trader.money_tot_start_period = trader.money_tot 
					end
				end
				compute_force_data(force_mem)
			end
			
			-- EVERY HOUR : update average display on opened traders and bar price
			
			for _, player in pairs(game.players) do
				if player.connected then
					local player_mem = global.player_mem[player.index]
					-- if player_mem.opened_trader then
						-- update_menu_trader(player,player_mem,false)
					-- end
					update_menu_gen(player,player_mem)
					update_bar(player)
				end
			end
		end
		
	elseif global.tick == 98 then
		if global.day_changed then
			-- day change

			debug_print("NEW DAY")
			global.day_changed = false
			
			-- EVERY DAY: compute day averages
			
			for name, force in pairs(game.forces) do
				local force_mem = global.force_mem[name]
				force_mem.credits_lastday = force_mem.credits - force_mem.credits_startday
				
				if force_mem.credits_startday == 0 then
					force_mem.var_lastday = 0
				else
					force_mem.var_lastday = 0.1 * math.floor(0.5+force_mem.credits_lastday * 1000 / force_mem.credits_startday)
				end
				
				force_mem.credits_startday = force_mem.credits
			end
			
			-- EVERY DAY : update dynamic prices , evolution price
			
			update_dynamic_prices()
			
			-- EVERY DAY: update all guis (new prices everywhere)
			
			update_guis(true)
		end
	end
	
	global.tick = global.tick + 1 
end

script.on_event(defines.events.on_tick, on_tick)

--------------------------------------------------------------------------------------
local function on_gui_click(event)
	local player = game.players[event.player_index]
	local force = player.force
	local player_mem = global.player_mem[player.index]
	local event_name = event.element.name
	local prefix = string.sub(event_name,1,15)
	local nix = tonumber(string.sub(event_name,16,18))
	local suffix = string.sub(event_name,19)
	
	if global.prices_computed then return end
	
	-- debug_print( "on_gui_click ", player.name, " ", event_name )

	if event_name == "but_blkmkt_main" then
		build_menu_gen(player,player_mem)
		update_menu_gen( player, player_mem )
		
	elseif event_name == "but_blkmkt_credits"then
		player_mem.ask_sel = nil
		build_menu_objects(player)

	elseif event_name == "but_blkmkt_gen_show_prices"then
		player_mem.ask_sel = nil
		build_menu_objects(player)
		
	elseif event_name == "but_blkmkt_gen_export_prices"then
		if debug_status == 1 then
			-- debug_print("RAZ")
			list_groups()
			list_techs_costs()
			list_prices()
			list_recipes()
		end
		
		export_prices()
		-- export_uncommons()
	
	elseif event_name == "but_blkmkt_gen_rescan_prices"then
		update_techs_costs()
		update_objects_prices_start()
		-- update_groups()
		
	elseif event_name == "chk_blkmkt_gen_pause" then
		local force_mem = global.force_mem[force.name]
		
		force_mem.pause = event.element.state
		
		update_guis_force(force,false)
		
	elseif event_name == "but_blkmkt_gen_auto_all"then
		local force_mem = global.force_mem[force.name]

		for _, trader in pairs(force_mem.traders_sell) do
			trader.auto = true
		end
	
		for _, trader in pairs(force_mem.traders_buy) do
			trader.auto = true
		end
	
		-- update_menu_trader(player,player_mem,false)
		update_guis_force(force,false)
		
	elseif event_name == "but_blkmkt_gen_auto_none"then
		local force_mem = global.force_mem[force.name]

		for _, trader in pairs(force_mem.traders_sell) do
			trader.auto = false
		end
	
		for _, trader in pairs(force_mem.traders_buy) do
			trader.auto = false
		end
	
		-- update_menu_trader(player,player_mem,false)
		update_guis_force(force,false)
		
	elseif event_name == "but_blkmkt_gen_sell_now"then
		local force_mem = global.force_mem[force.name]
		local money = 0
		
		for i=#force_mem.traders_sell,1,-1 do
			local trader = force_mem.traders_sell[i]
			local ent = trader.entity
			local money1 = sell_trader(trader,force_mem)
			if money1 == nil then
				table.remove(force_mem.traders_sell,i)
			else
				money = money + money1
			end
		end
		if money ~= 0 then
			compute_force_data(force_mem)
			update_guis_force(force,false)
			-- update_bars(force)
			-- update_menu_gen(player,player_mem)
			-- update_menu_trader(player,player_mem,true)
		end
		
	elseif event_name == "but_blkmkt_gen_buy_now"then
		local force_mem = global.force_mem[force.name]
		local money = 0
		
		for i=#force_mem.traders_buy,1,-1 do
			local trader = force_mem.traders_buy[i]
			local ent = trader.entity
			local money1 = buy_trader(trader,force_mem)
			if money1 == nil then
				-- debug_print("buy !" )
				table.remove(force_mem.traders_buy,i)
			else
				money = money + money1
			end
		end
		
		if money ~= 0 then
			compute_force_data(force_mem)
			update_guis_force(force,false)
			-- update_bars(force)
			-- update_menu_gen(player,player_mem)
			-- update_menu_trader(player,player_mem,true)
		end
		
	elseif event_name == "but_blkmkt_gen_period_down" then
		build_menu_objects(player,false)

		local force_mem = global.force_mem[force.name]

		if force_mem.n_period > 2 then
			force_mem.n_period = force_mem.n_period - 1
			force_mem.period = periods[force_mem.n_period]
		end
		
		-- update_menu_gen(player,player_mem)
		update_guis_force(force,false)
		
	elseif event_name == "but_blkmkt_gen_period_up" then
		build_menu_objects(player,false)

		local force_mem = global.force_mem[force.name]

		if force_mem.n_period < #periods then
			force_mem.n_period = force_mem.n_period + 1
			force_mem.period = periods[force_mem.n_period]
		end
		
		-- update_menu_gen(player,player_mem)
		update_guis_force(force,false)
		
	elseif event_name == "but_blkmkt_gen_period_set" then
		build_menu_objects(player,false)

		local force_mem = global.force_mem[force.name]

		for _, trader in pairs(force_mem.traders_sell) do
			trader.n_period = force_mem.n_period
			trader.period = force_mem.period
		end
		
		for _, trader in pairs(force_mem.traders_buy) do
			trader.n_period = force_mem.n_period
			trader.period = force_mem.period
		end

		-- update_menu_trader(player,player_mem,false)
		update_guis_force(force,false)

	elseif event_name == "but_blkmkt_gen_close" then
		build_menu_gen(player,player_mem,false)

	elseif prefix == "but_blkmkt_ilg_" then -- click group in item list
		-- debug_print(suffix)
		player_mem.group_sel_name = suffix
		build_menu_objects(player,true,player_mem.ask_sel)

	elseif prefix == "but_blkmkt_ili_" then -- click item in item list
		-- debug_print(suffix)
		player_mem.object_sel_name = suffix

		local trader = player_mem.opened_trader
		
		if trader and player_mem.order_sel_n ~= 0 then
			build_menu_objects(player,false)
			
			local order = trader.orders[player_mem.order_sel_n]
			
			if order then
				order.name = player_mem.object_sel_name
			end
			
			compute_trader_data(trader,true)
			-- update_menu_trader(player,player_mem,true)
			player_mem.order_sel_n = 0
		end
		
	elseif event_name == "but_blkmkt_itml_refresh" then
		build_menu_objects(player,true,player_mem.ask_sel)
		
	elseif event_name == "but_blkmkt_itml_close" then
		build_menu_objects(player,false)
		
	elseif event_name == "but_blkmkt_itml_cancel" then
		player_mem.order_sel_n = 0
		
		build_menu_objects(player,false)
		
	elseif event_name == "chk_blkmkt_trader_auto" then
		build_menu_objects(player,false)
		
		player_mem.opened_trader.auto = player_mem.chk_blkmkt_trader_auto.state
		
	elseif event_name == "but_blkmkt_trader_now" then -- sell or buy trader now
		build_menu_objects(player,false)
		
		local force_mem = global.force_mem[force.name]
		local trader = player_mem.opened_trader
		
		if trader.sell_or_buy then
			sell_trader(trader,force_mem,global.tax_rates[0])
		else
			buy_trader(trader,force_mem,global.tax_rates[0])
		end
		compute_trader_data(trader, false)
		-- update_menu_trader(player,player_mem,false)
		update_bars(force)
		
	elseif event_name == "chk_blkmkt_trader_daylight" then
		build_menu_objects(player,false)
		
		player_mem.opened_trader.daylight = player_mem.chk_blkmkt_trader_daylight.state
		
	elseif event_name == "but_blkmkt_trader_period_down" then
		build_menu_objects(player,false)
		
		local trader = player_mem.opened_trader
		
		if trader.n_period > 2 then
			trader.n_period = trader.n_period - 1
			trader.period = periods[trader.n_period]
		end
		
		update_menu_trader(player,player_mem,false)
		
	elseif event_name == "but_blkmkt_trader_period_up" then
		build_menu_objects(player,false)
		
		local trader = player_mem.opened_trader
		
		if trader.n_period < #periods then
			trader.n_period = trader.n_period + 1
			trader.period = periods[trader.n_period]
		end
		
		update_menu_trader(player,player_mem,false)
		
	elseif event_name == "but_blkmkt_trader_evaluate" then
		build_menu_objects(player,false)
		
		evaluate_trader(player_mem.opened_trader)
		update_menu_trader(player,player_mem,false)
		
	elseif event_name == "but_blkmkt_trader_reset" then
		build_menu_objects(player,false)
		
		local trader = player_mem.opened_trader
		
		trader.hour = trader.hour_period
		trader.money_reset = trader.money_tot
		trader.taxes_reset = trader.taxes_tot
		trader.money = 0
		trader.taxes = 0
		trader.money_average = 0
		
		compute_trader_data(trader,false)
		-- update_menu_trader(player,player_mem,false)

	elseif event_name == "but_blkmkt_trader_new" then -- new order
		build_menu_objects(player,false)
		
		local trader = player_mem.opened_trader
		
		if trader.type == trader_type.item then
			if #trader.orders < 99 then
				table.insert(trader.orders,1,{name="coal", count=0, price=global.prices.coal.current})
				update_menu_trader(player,player_mem,true)
			end
		end
	
	elseif event_name == "but_blkmkt_trader_wipe" then -- wipe orders
		build_menu_objects(player,false)
		
		local trader = player_mem.opened_trader
		
		if trader.type == trader_type.item then
			trader.orders = {}
			compute_trader_data(trader,true)
			-- update_menu_trader(player,player_mem,true)
		end
	
	elseif prefix == "but_blkmkt_ord_" then -- del item in orders list
		build_menu_objects(player,false)
		
		local trader = player_mem.opened_trader
		-- debug_print(nix, " ", suffix)
		
		if trader.type == trader_type.item then
			table.remove(trader.orders,nix)
			compute_trader_data(trader,true)
			-- update_menu_trader(player,player_mem,true)
		end

	elseif prefix == "but_blkmkt_ori_" then -- change order's item
		-- debug_print(nix, " ", suffix)
		
		local trader = player_mem.opened_trader
		
		if trader.type ~= trader_type.energy then
			player_mem.order_sel_n = nix
			player_mem.ask_sel = trader_type[trader.type]
			if player_mem.ask_sel == "fluid" then
				player_mem.group_sel_name = "fluids"
			end
			build_menu_objects(player,true,player_mem.ask_sel)
		end
	end
end

script.on_event(defines.events.on_gui_click, on_gui_click)
script.on_event(defines.events.on_gui_checked_state_changed, on_gui_click)

--------------------------------------------------------------------------------------
local function on_gui_text_changed(event)
	local player = game.players[event.player_index]
	local event_name = event.element.name
	local prefix = string.sub(event_name,1,15)
	local nix = tonumber(string.sub(event_name,16,18))
	local suffix = string.sub(event_name,19)

	-- debug_print( "on_gui_text_changed ", player.name, " ", event_name )
	
	if prefix == "but_blkmkt_orc_" then -- change order count
		local player_mem = global.player_mem[player.index]
		local trader = player_mem.opened_trader
		
		-- debug_print(nix, " ", suffix, " ", trader.orders[nix].count)
		
		local count = tonumber(event.element.text)
		if count ~= nil then
			trader.orders[nix].count = count
			compute_trader_data(trader,false)
			-- update_menu_trader(player,player_mem,false)
		end
	end
end

script.on_event(defines.events.on_gui_text_changed,on_gui_text_changed)

--------------------------------------------------------------------------------------
local interface = {}

function interface.reset()
	debug_print( "reset" )
	
	for _,force in pairs(game.forces) do
		force.reset_recipes()
		force.reset_technologies()
		local force_mem = global.force_mem[force.name]
		force_mem.credits = n
		force_mem.pause = false 
		force_mem.credits = 0
		force_mem.sales = 0
		force_mem.sales_taxes = 0
		force_mem.purchases = 0
		force_mem.purchases_taxes = 0
		force_mem.tax_rate = 0
		force_mem.transactions = {} 
		
		compute_force_data(force_mem)
		
		for _, trader in pairs(force_mem.traders_sell) do
			init_trader(trader,nil)
			compute_trader_data(trader)
		end
		
		for _, trader in pairs(force_mem.traders_buy) do
			init_trader(trader,nil)
			compute_trader_data(trader)
		end
	end

	for _, player in pairs(game.players) do
		if mod_gui.get_button_flow(player).flw_blkmkt then player.gui.top.flw_blkmkt.destroy() end
		init_player(player)
		local player_mem = global.player_mem[player.index]
		update_menu_gen(player,player_mem)
		update_menu_trader(player,player_mem,false)
	end
end

function interface.prices()
	debug_print( "prices" )
	
	update_techs_costs()
	update_objects_prices_start()
	-- update_groups()
end

function interface.credits(n)
	debug_print( "credits" )
	
	for _,force in pairs(game.forces) do
		local force_mem = global.force_mem[force.name]
		force_mem.credits = n
	end
	
	for _, player in pairs(game.players) do
		update_bar(player)
	end
end

function interface.get_credits(force_name)
	
	local force_mem = global.force_mem[force_name]
	return force_mem.credits
end

remote.add_interface( "market", interface )

-- /c remote.call( "market", "reset" )
-- /c remote.call( "market", "prices" )
-- /c remote.call( "market", "credits", 1000000 )
