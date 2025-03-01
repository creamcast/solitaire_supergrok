require 'gosu'
require 'set'

class Card
  attr_accessor :id, :name, :image_front, :image_back, :x, :y, :face_up,
                :flipping, :flip_progress, :target_face_up,
                :dragging, :drag_offset_x, :drag_offset_y, :frozen,
                :flip_start_time, :z

  FLIP_DURATION = 200
  CARD_WIDTH = 352 * 0.2
  CARD_HEIGHT = 512 * 0.2

  def initialize(id, name, image_front, image_back)
    @id = id
    @name = name
    @image_front = image_front
    @image_back = image_back
    @x = nil
    @y = nil
    @face_up = false
    @flipping = false
    @flip_progress = 0.0
    @target_face_up = false
    @dragging = false
    @drag_offset_x = 0
    @drag_offset_y = 0
    @frozen = false
    @z = 0
  end

  def start_dragging(mx, my)
    @dragging = true
    @drag_offset_x = mx - @x
    @drag_offset_y = my - @y
  end

  def stop_dragging
    @dragging = false
  end

  def move_to(x, y)
    @x = x
    @y = y
  end

  def flip
    return if @flipping
    @flipping = true
    @target_face_up = !@face_up
    @flip_progress = 0.0
    @flip_start_time ||= Gosu.milliseconds
  end

  def update(current_time)
    if @flipping
      elapsed = current_time - (@flip_start_time || Gosu.milliseconds)
      @flip_progress = [elapsed.to_f / FLIP_DURATION, 1.0].min
      if @flip_progress >= 1.0
        @face_up = @target_face_up
        @flipping = false
      end
    end
  end

  def draw(scale = 0.2)
    return unless @x && @y
    if @flipping
      progress = @flip_progress
      image = progress < 0.5 ? (@face_up ? @image_front : @image_back) : (@target_face_up ? @image_front : @image_back)
      scale_x = progress < 0.5 ? (1 - 2 * progress) : (2 * (progress - 0.5))
      center_x = @x + CARD_WIDTH / 2
      new_x = center_x - (CARD_WIDTH * scale_x / 2)
      image.draw(new_x, @y, @z, scale_x * scale, scale)
    else
      image = @face_up ? @image_front : @image_back
      image.draw(@x, @y, @z, scale, scale)
    end
  end

  def freeze
    @frozen = true
  end

  def unfreeze
    @frozen = false
  end
end

class SolitaireWindow < Gosu::Window
  WINDOW_WIDTH = 575
  WINDOW_HEIGHT = 700
  SCALE = 0.2
  CARD_WIDTH = 352 * SCALE
  CARD_HEIGHT = 512 * SCALE
  SPACING = 10
  FOUNDATION_START_X = 250
  FOUNDATION_Y = 10
  FOUNDATION_WIDTH = CARD_WIDTH
  FOUNDATION_HEIGHT = CARD_HEIGHT
  SUIT_NAMES = ['Spades', 'Hearts', 'Diamonds', 'Clubs']

  def initialize
    super(WINDOW_WIDTH, WINDOW_HEIGHT, false)
    self.caption = "Solitaire"
    @cards = {}
    @tableau = []
    @foundations = []
    @stock = []
    @waste = []
    @dragging_cards = []
    @drag_start_positions = []
    @console_active = false
    @console_input = Gosu::TextInput.new
    @console_font = Gosu::Font.new(20)
    @foundation_font = Gosu::Font.new(12)  # Font for foundation labels
    @game_won = false  # Track if the game is won
    @points = 0        # Track player points
    load_card_images
    create_cards
    setup_game
  end

  def load_card_images
    @card_images = {}
    rank_to_file = {
      '2' => '02', '3' => '03', '4' => '04', '5' => '05', '6' => '06',
      '7' => '07', '8' => '08', '9' => '09', '10' => '10',
      'jack' => 'jack', 'queen' => 'queen', 'king' => 'king', 'ace' => 'ace'
    }
    suits = ['hearts', 'diamonds', 'clubs', 'spades']
    ranks = ['2', '3', '4', '5', '6', '7', '8', '9', '10', 'jack', 'queen', 'king', 'ace']
    suits.each do |suit|
      ranks.each do |rank|
        card_name = "#{rank} of #{suit}"
        @card_images[card_name] = Gosu::Image.new("cards/#{suit}_#{rank_to_file[rank]}.png")
      end
    end
    @back_image = Gosu::Image.new("cards/back05.png")
  end

  def create_cards
    suits = ['hearts', 'diamonds', 'clubs', 'spades']
    ranks = ['2', '3', '4', '5', '6', '7', '8', '9', '10', 'jack', 'queen', 'king', 'ace']
    ranks.product(suits).each do |rank, suit|
      card_id = "#{rank}_#{suit}"
      card_name = "#{rank} of #{suit}"
      @cards[card_id] = Card.new(card_id, card_name, @card_images[card_name], @back_image)
    end
  end

  def setup_game
    all_cards = @cards.values.shuffle
    @tableau = []
    7.times do |i|
      pile = all_cards.shift(i + 1)
      pile.each { |card| card.face_up = false }
      pile.last.face_up = true
      @tableau << pile
    end
    @stock = all_cards
    @stock.each { |card| card.face_up = false }
    @foundations = Array.new(4) { [] }
    @waste = []
    @points = 0
    @game_won = false
    position_cards
  end

  def position_cards
    z_index = 0
    @tableau.each_with_index do |pile, pile_index|
      x = 10 + pile_index * (CARD_WIDTH + SPACING)
      pile.each_with_index do |card, card_index|
        if !@dragging_cards.include?(card)
          y = 130 + card_index * 30
          card.move_to(x, y)
          card.z = z_index
        end
        z_index += 1
      end
    end
    stock_x = 10
    stock_y = 10
    @stock.each do |card|
      if !@dragging_cards.include?(card)
        card.move_to(stock_x, stock_y)
        card.z = z_index
      end
      z_index += 1
    end
    waste_x = 90
    waste_y = 10
    @waste.each do |card|
      if !@dragging_cards.include?(card)
        card.move_to(waste_x, waste_y)
        card.z = z_index
      end
      z_index += 1
    end
    @foundations.each_with_index do |pile, pile_index|
      x = FOUNDATION_START_X + pile_index * (CARD_WIDTH + SPACING)
      y = FOUNDATION_Y
      pile.each do |card|
        if !@dragging_cards.include?(card)
          card.move_to(x, y)
          card.z = z_index
        end
        z_index += 1
      end
    end
  end

  def button_down(id)
    if @console_active
      if id == Gosu::KB_RETURN
        execute_command(@console_input.text)
        @console_input.text = ""
        @console_active = false
        self.text_input = nil
      elsif id == Gosu::KB_ESCAPE
        @console_input.text = ""
        @console_active = false
        self.text_input = nil
      end
    else
      if id == Gosu::KB_BACKTICK
        @console_active = true
        self.text_input = @console_input
        @console_input.text = ""
      elsif id == Gosu::MsLeft
        if @game_won
          mx, my = mouse_x, mouse_y
          box_width = 300
          box_height = 100
          box_x = (WINDOW_WIDTH - box_width) / 2
          box_y = (WINDOW_HEIGHT - box_height) / 2
          if mx >= box_x && mx <= box_x + box_width && my >= box_y && my <= box_y + box_height
            setup_game
          end
        else
          mx, my = mouse_x, mouse_y
          if mx >= 10 && mx <= 10 + CARD_WIDTH && my >= 10 && my <= 10 + CARD_HEIGHT
            if @stock.empty? && !@waste.empty?
              @points -= 100  # Penalty for resetting stock
              @stock = @waste.reverse
              @waste = []
              @stock.each { |card| card.face_up = false }
              position_cards
            elsif !@stock.empty?
              card = @stock.pop
              card.face_up = true
              @waste << card
              position_cards
            end
          else
            clicked_card = nil
            clicked_pile = nil
            clicked_index = nil
            pile_index = nil
            @tableau.each_with_index do |pile, p_index|
              (pile.size - 1).downto(0) do |c_index|
                card = pile[c_index]
                if card.x && card.y && mx >= card.x && mx <= card.x + CARD_WIDTH && my >= card.y && my <= card.y + CARD_HEIGHT
                  clicked_card = card
                  clicked_pile = :tableau
                  clicked_index = c_index
                  pile_index = p_index
                  break
                end
              end
              break if clicked_card
            end
            if !clicked_card && !@waste.empty?
              card = @waste.last
              if mx >= card.x && mx <= card.x + CARD_WIDTH && my >= card.y && my <= card.y + CARD_HEIGHT
                clicked_card = card
                clicked_pile = :waste
                clicked_index = @waste.size - 1
              end
            end
            if !clicked_card
              @foundations.each_with_index do |pile, p_index|
                if !pile.empty?
                  card = pile.last
                  if mx >= card.x && mx <= card.x + CARD_WIDTH && my >= card.y && my <= card.y + CARD_HEIGHT
                    clicked_card = card
                    clicked_pile = :foundation
                    clicked_index = pile.size - 1
                    pile_index = p_index
                    break
                  end
                end
              end
            end
            if clicked_card && !clicked_card.frozen
              if clicked_pile == :tableau
                pile = @tableau[pile_index]
                if pile[clicked_index].face_up
                  potential_sequence = pile[clicked_index..-1]
                  @dragging_cards = valid_sequence?(potential_sequence) ? potential_sequence : []
                else
                  @dragging_cards = []
                end
              elsif clicked_pile == :waste
                @dragging_cards = [clicked_card]
              elsif clicked_pile == :foundation
                @dragging_cards = (clicked_index == @foundations[pile_index].size - 1) ? [clicked_card] : []
              end
              if @dragging_cards.any?
                @dragging_cards.first.start_dragging(mx, my)
                @drag_start_positions = @dragging_cards.map { |c| [c.x, c.y] }
              end
            end
          end
        end
      end
    end
  end

  def button_up(id)
    if id == Gosu::MsLeft && @dragging_cards.any?
      mx, my = mouse_x, mouse_y
      target_pile = nil
      target_pile_index = nil
      if my >= FOUNDATION_Y && my <= FOUNDATION_Y + FOUNDATION_HEIGHT
        @foundations.each_with_index do |pile, i|
          pile_x = FOUNDATION_START_X + i * (CARD_WIDTH + SPACING)
          if mx >= pile_x && mx <= pile_x + FOUNDATION_WIDTH
            target_pile = :foundation
            target_pile_index = i
            break
          end
        end
      end
      if !target_pile
        @tableau.each_with_index do |pile, i|
          pile_x = 10 + i * (CARD_WIDTH + SPACING)
          if mx >= pile_x && mx <= pile_x + CARD_WIDTH
            target_pile = :tableau
            target_pile_index = i
            break
          end
        end
      end
      if target_pile
        if valid_move?(@dragging_cards, target_pile, target_pile_index)
          source_pile = find_source_pile(@dragging_cards.first)
          if source_pile
            source_pile_type, source_pile_index = source_pile
            case source_pile_type
            when :tableau
              @tableau[source_pile_index].delete_if { |c| @dragging_cards.include?(c) }
              if !@tableau[source_pile_index].empty? && !@tableau[source_pile_index].last.face_up
                @tableau[source_pile_index].last.face_up = true
                @points += 5
              end
            when :waste
              @waste.delete(@dragging_cards.first)
            when :foundation
              @foundations[source_pile_index].delete(@dragging_cards.first)
            end
            case target_pile
            when :tableau
              @tableau[target_pile_index] += @dragging_cards
            when :foundation
              @foundations[target_pile_index] += @dragging_cards
              @points += 10 * @dragging_cards.size
            end
            position_cards
            if check_win_condition
              @game_won = true
            end
          end
        else
          @points -= 5  # Penalty for invalid move
          @dragging_cards.each_with_index { |card, i| card.move_to(@drag_start_positions[i][0], @drag_start_positions[i][1]) }
        end
      else
        @dragging_cards.each_with_index { |card, i| card.move_to(@drag_start_positions[i][0], @drag_start_positions[i][1]) }
      end
      @dragging_cards = []
    end
  end

  def update
    current_time = Gosu.milliseconds
    @cards.each_value { |card| card.update(current_time) }
    if @dragging_cards.any?
      first_card = @dragging_cards.first
      first_card.move_to(mouse_x - first_card.drag_offset_x, mouse_y - first_card.drag_offset_y)
      @dragging_cards[1..-1].each_with_index do |card, i|
        dx = @drag_start_positions[i + 1][0] - @drag_start_positions[0][0]
        dy = @drag_start_positions[i + 1][1] - @drag_start_positions[0][1]
        card.move_to(first_card.x + dx, first_card.y + dy)
      end
      @dragging_cards.each_with_index do |card, index|
        card.z = 1000 + index
      end
    end
    position_cards
  end

  def draw
    Gosu.draw_rect(0, 0, WINDOW_WIDTH, WINDOW_HEIGHT, Gosu::Color::GREEN)
    @foundations.each_with_index do |pile, i|
      if pile.empty?
        x = FOUNDATION_START_X + i * (CARD_WIDTH + SPACING)
        y = FOUNDATION_Y
        Gosu.draw_rect(x, y, FOUNDATION_WIDTH, FOUNDATION_HEIGHT, Gosu::Color.new(0, 100, 0), z = 0)
        text = SUIT_NAMES[i]
        text_width = @foundation_font.text_width(text)
        @foundation_font.draw_text(text, x + (FOUNDATION_WIDTH - text_width) / 2, y + (FOUNDATION_HEIGHT - @foundation_font.height) / 2, 0, 1.0, 1.0, Gosu::Color::WHITE)
      end
    end
    @cards.each_value { |card| card.draw(SCALE) }
    if @console_active
      Gosu.draw_rect(0, 0, WINDOW_WIDTH, 30, Gosu::Color.argb(0xAA_808080), z = 2000)
      @console_font.draw_text("> #{@console_input.text}", 10, 5, 2001, 1.0, 1.0, Gosu::Color::WHITE)
    end
    if @game_won
      box_width = 300
      box_height = 100
      box_x = (WINDOW_WIDTH - box_width) / 2
      box_y = (WINDOW_HEIGHT - box_height) / 2
      Gosu.draw_rect(box_x, box_y, box_width, box_height, Gosu::Color::YELLOW, z = 2002)
      win_font = Gosu::Font.new(50)
      text = "You win!"
      text_width = win_font.text_width(text)
      win_font.draw_text(text, box_x + (box_width - text_width) / 2, box_y + (box_height - win_font.height) / 2, 2003, 1.0, 1.0, Gosu::Color::BLACK)
    end
    points_text = "Points: #{@points}"
    @console_font.draw_text(points_text, 10, WINDOW_HEIGHT - 30, 1, 1.0, 1.0, Gosu::Color::BLACK)  # Changed to black
  end

  def check_win_condition
    @foundations.all? { |pile| pile.size == 13 }
  end

  def valid_sequence?(cards)
    return true if cards.size == 1
    cards.each_cons(2) do |card1, card2|
      rank1 = card1.name.split(' of ')[0]
      suit1 = card1.name.split(' of ')[1]
      rank2 = card2.name.split(' of ')[0]
      suit2 = card2.name.split(' of ')[1]
      color1 = ['hearts', 'diamonds'].include?(suit1) ? 'red' : 'black'
      color2 = ['hearts', 'diamonds'].include?(suit2) ? 'red' : 'black'
      return false unless rank_value(rank1) == rank_value(rank2) + 1 && color1 != color2
    end
    true
  end

  def valid_move?(cards, target_pile_type, target_pile_index)
    if target_pile_type == :tableau
      target_pile = @tableau[target_pile_index]
      if target_pile.empty?
        return cards.first.name.start_with?("king")
      else
        return can_place_on(cards.first, target_pile.last)
      end
    elsif target_pile_type == :foundation
      return false if cards.size > 1
      card = cards.first
      foundation = @foundations[target_pile_index]
      suit = card.name.split(' of ')[1]
      if foundation.empty?
        return card.name.start_with?("ace") && suit == SUIT_NAMES[target_pile_index].downcase
      else
        top_card = foundation.last
        return top_card.name.split(' of ')[1] == suit && rank_value(card.name.split(' of ')[0]) == rank_value(top_card.name.split(' of ')[0]) + 1
      end
    end
    false
  end

  def can_place_on(card, top_card)
    rank1 = card.name.split(' of ')[0]
    suit1 = card.name.split(' of ')[1]
    rank2 = top_card.name.split(' of ')[0]
    suit2 = top_card.name.split(' of ')[1]
    color1 = ['hearts', 'diamonds'].include?(suit1) ? 'red' : 'black'
    color2 = ['hearts', 'diamonds'].include?(suit2) ? 'red' : 'black'
    rank_value(rank1) == rank_value(rank2) - 1 && color1 != color2
  end

  def rank_value(rank)
    case rank
    when 'ace' then 1
    when 'jack' then 11
    when 'queen' then 12
    when 'king' then 13
    else rank.to_i
    end
  end

  def find_source_pile(card)
    @tableau.each_with_index { |pile, i| return [:tableau, i] if pile.include?(card) }
    return [:waste, nil] if @waste.include?(card)
    @foundations.each_with_index { |pile, i| return [:foundation, i] if pile.include?(card) }
    nil
  end

  def execute_command(command)
    case command.downcase
    when "reset"
      setup_game
      puts "Game reset"
    else
      puts "Unknown command: '#{command}'"
    end
  end
end

if __FILE__ == $0
  window = SolitaireWindow.new
  window.show
end
