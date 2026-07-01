#===============================================================================
# PERSISTENT DEVELOPER MENU - Pokemon Essentials (v15-v21+)
# Universal Enterprise Architecture
#===============================================================================
module DeveloperMenu
  LANG = 'en'
  LANG_KEYS = {
    "en" => "English",
    "pt" => "Portugues",
    "es" => "Espanol"
  }
  MENU_HOTKEY = 'F6'
  WTW_HOTKEY = 'F5'
  HEAL_HOTKEY = 'F9'
  TR = {
    :dev_menu => {"English" => "DEVELOPER MENU", "Portugues" => "MENU DO DESENVOLVEDOR", "Espanol" => "MENU DE DESARROLLADOR"},
    :engine => {"English" => "Engine", "Portugues" => "Motor do Jogo", "Espanol" => "Motor"},
    :pokemon => {"English" => "Pokemon", "Portugues" => "Pokemon", "Espanol" => "Pokemon"},
    :items => {"English" => "Items", "Portugues" => "Itens", "Espanol" => "Objetos"},
    :Player => {"English" => "Player", "Portugues" => "Jogador", "Espanol" => "Jugador"},
    :party => {"English" => "Party", "Portugues" => "Equipe", "Espanol" => "Equipo"},
    :extras => {"English" => "Extras", "Portugues" => "Extras", "Espanol" => "Extras"},
    :back => {"English" => "Back/Cancel", "Portugues" => "Voltar/Cancelar", "Espanol" => "Volver/Cancelar"},
    
    :warp => {"English" => "Warp to Map", "Portugues" => "Teleporte de Mapa", "Espanol" => "Teletransporte"},
    :switches => {"English" => "Switches", "Portugues" => "Interruptores", "Espanol" => "Interruptores"},
    :vars => {"English" => "Variables", "Portugues" => "Variaveis", "Espanol" => "Variables"},
    :safari => {"English" => "Safari / Contest", "Portugues" => "Safari / Torneio", "Espanol" => "Safari / Torneo"},
    :Field => {"English" => "Field Effects", "Portugues" => "Efeitos de Campo", "Espanol" => "Efectos de Campo"},
    :refresh => {"English" => "Refresh Map", "Portugues" => "Atualizar Mapa", "Espanol" => "Actualizar Mapa"},
    :daycare => {"English" => "Day Care", "Portugues" => "Creche (Day Care)", "Espanol" => "Guarderia"},
    :Wallpapers => {"English" => "Toggle PC Wallpapers", "Portugues" => "Desbloquear Wallpapers do PC", "Espanol" => "Desbloquear Fondos de PC"},
    :Battle => {"English" => "Test Wild Battle", "Portugues" => "Testar Batalha", "Espanol" => "Probar Batalla"},
    :expall => {"English" => "Toggle Exp. All", "Portugues" => "Alternar Exp. All", "Espanol" => "Alternar Exp. All"},
    :wtw => {"English" => "Toggle Walk Through Walls", "Portugues" => "Atravessar Paredes", "Espanol" => "Atravesar Paredes"},
    :openpc => {"English" => "Open PC", "Portugues" => "Abrir PC", "Espanol" => "Abrir PC"},
    
    :FillPC => {"English" => "Fill PC Boxes", "Portugues" => "Encher Caixas do PC", "Espanol" => "Llenar Cajas del PC"},
    :ClearPC => {"English" => "Clear PC Boxes", "Portugues" => "Limpar Caixas do PC", "Espanol" => "Vaciar Cajas del PC"},
    :addboxes => {"English" => "Add PC Boxes", "Portugues" => "Adicionar Caixas", "Espanol" => "Anadir Cajas al PC"},
    :quickhatch => {"English" => "Quick Hatch Party Eggs", "Portugues" => "Chocar Ovos Rapido", "Espanol" => "Eclosionar Huevos"},
    :addpkmn => {"English" => "Add Pokemon", "Portugues" => "Adicionar Pokemon", "Espanol" => "Anadir Pokemon"},
    :Heal => {"English" => "Heal Party", "Portugues" => "Curar Equipe", "Espanol" => "Curar Equipo"},
    :exportids => {"English" => "Export Species IDs", "Portugues" => "Exportar IDs", "Espanol" => "Exportar IDs"},
    
    :additem => {"English" => "Add Item", "Portugues" => "Adicionar Item", "Espanol" => "Anadir Objeto"},
    :fillbag => {"English" => "Fill Bag (All)", "Portugues" => "Encher Mochila (Tudo)", "Espanol" => "Llenar Mochila (Todo)"},
    :fillbagnon => {"English" => "Fill Bag (Non-Key)", "Portugues" => "Encher Mochila (Sem Itens Chave)", "Espanol" => "Llenar Mochila (Sin Objetos Clave)"},
    :fillbagkey => {"English" => "Fill Bag (Key Items)", "Portugues" => "Encher Mochila (So Itens Chave)", "Espanol" => "Llenar Mochila (Solo Clave)"},
    :emptybag => {"English" => "Empty Bag", "Portugues" => "Esvaziar Mochila", "Espanol" => "Vaciar Mochila"},
    
    :money => {"English" => "Edit Money", "Portugues" => "Editar Dinheiro", "Espanol" => "Editar Dinero"},
    :coins => {"English" => "Edit Coins", "Portugues" => "Editar Moedas", "Espanol" => "Editar Monedas"},
    :bp => {"English" => "Edit Battle Points", "Portugues" => "Editar BP", "Espanol" => "Editar BP"},
    :badges => {"English" => "Toggle All Badges", "Portugues" => "Obter Todas as Insignias", "Espanol" => "Obtener Medallas"},
    :pokedex => {"English" => "Complete Pokedex", "Portugues" => "Completar Pokedex", "Espanol" => "Completar Pokedex"},
    :fly => {"English" => "Unlock Fly Destinations", "Portugues" => "Desbloquear Voo (Fly)", "Espanol" => "Desbloquear Vuelo"},
    :name => {"English" => "Rename Player", "Portugues" => "Renomear Jogador", "Espanol" => "Renombrar Jugador"},
    :gender => {"English" => "Change Gender", "Portugues" => "Mudar Genero", "Espanol" => "Cambiar Genero"},
    :outfit => {"English" => "Change Outfit", "Portugues" => "Mudar Roupa", "Espanol" => "Cambiar Ropa"},
    :character => {"English" => "Player Character", "Portugues" => "Mudar Personagem", "Espanol" => "Cambiar Personaje"},
    :trainerid => {"English" => "Change Trainer ID", "Portugues" => "Mudar ID de Treinador", "Espanol" => "Cambiar ID"},
    :playtime => {"English" => "Edit Play Time", "Portugues" => "Editar Tempo de Jogo", "Espanol" => "Editar Tiempo Jugado"},
    :pokedex_tog => {"English" => "Toggle Pokedex", "Portugues" => "Obter Pokedex", "Espanol" => "Obtener Pokedex"},
    :pokegear => {"English" => "Toggle Pokegear", "Portugues" => "Obter Pokegear", "Espanol" => "Obtener Pokegear"},
    :shoes => {"English" => "Toggle Running Shoes", "Portugues" => "Tenis de Corrida", "Espanol" => "Zapatillas"},
    :ash => {"English" => "Edit Ash Count", "Portugues" => "Editar Cinzas (Ash)", "Espanol" => "Editar Cenizas"},
    :region => {"English" => "Change Region", "Portugues" => "Mudar Regiao", "Espanol" => "Cambiar Region"},
    :partner => {"English" => "Edit Partner", "Portugues" => "Remover Parceiro (Partner)", "Espanol" => "Quitar Companero"},
    :nobattles => {"English" => "Toggle No Battles", "Portugues" => "Batalhas: Nenhuma", "Espanol" => "Sin Batallas"},
    :infmega => {"English" => "Toggle Inf. Mega", "Portugues" => "Mega Evolucao Infinita", "Espanol" => "Mega Evolucion Infinita"},
    :nativedebug => {"English" => "Open Native Debug Menu", "Portugues" => "Abrir Debug Nativo", "Espanol" => "Abrir Debug Nativo"}
  }

