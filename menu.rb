# Copyright 2019 Victor David Santos
#
# This file is part of Super Bombinhas.
#
# Super Bombinhas is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# Super Bombinhas is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with Super Bombinhas.  If not, see <https://www.gnu.org/licenses/>.

require 'minigl'
require_relative 'world'
require_relative 'player'
require_relative 'options'
include MiniGL

class SavedGameButton < Button
  include FormElement

  def initialize(x, y)
    super(x: x, y: y, width: 368, height: 80)
  end
end

class NewGameButton < Button
  include FormElement

  attr_reader :text_id

  def initialize(index, x, y, menu)
    super(x: x, y: y, width: 368, height: 80) {
      menu.go_to_new_game(@index - 1)
      SB.play_sound @sound
    }
    @index = index
    @img = Res.img(:ui_bgGameSlot)
    @text = SB.text(:new_game)
    @text_id = :new_game
    @sound = Res.sound :btn1
  end

  def draw(alpha = 0xff, z_index = 0)
    @img.draw @x, @y, 0, 2, 2
    SB.font.draw_text_rel @index.to_s, @x + 365, @y + 40, 0, 1, 0.5, 3, 3, 0x80000000
    SB.text_helper.write_line(@text, @x + 185, @y + 24, :center, 0xffffff, 255, :border, 0, 2, 255, 0, 3, 3)
  end
end

class SavedGame
  include FormElement

  def initialize(index, x, y, name, bomb, world_stage, specs, score)
    @index = index
    @x = x
    @y = y
    @name = name
    @world_stage = world_stage
    @specs = specs.split(',').size
    @score = score
    @bg = Res.img(:ui_bgGameSlot)
    @bomb = Res.img("icon_Bomba#{bomb.capitalize}")
    @map_icon = Res.img(:icon_map)
    @spec_icon = Res.img(:icon_spec)
    @score_icon = Res.img(:icon_score)
  end

  def update; end

  def set_position(x, y)
    @x = x; @y = y
  end

  def draw
    @bg.draw @x, @y, 0, 2, 2
    @bomb.draw @x + 5, @y + 5, 0, 2, 2
    @map_icon.draw @x + 45, @y + 40, 0, 2, 2
    @spec_icon.draw @x + 135, @y + 40, 0, 2, 2
    @score_icon.draw @x + 227, @y + 40, 0, 2, 2
    SB.font.draw_text_rel @index.to_s, @x + 365, @y + 40, 0, 1, 0.5, 3, 3, 0x80000000
    SB.text_helper.write_line @name, @x + 45, @y + 5, :left, 0xffffff, 255, :border, 0, 2, 255, 0, 3, 3
    SB.text_helper.write_line @world_stage, @x + 75, @y + 43
    SB.text_helper.write_line @specs.to_s, @x + 165, @y + 43
    SB.text_helper.write_line @score, @x + 255, @y + 43
  end
end

class Menu
  class << self
    def initialize
      @bg = Res.img :bg_start1, true
      @title = Res.img :ui_title, true

      @form = Form.new([
        MenuButton.new(270, :play) {
          @form.go_to_section 1
        },
        MenuButton.new(320, :help) {
          @form.go_to_section 7
        },
        MenuButton.new(370, :options) {
          Options.set_temp
          @form.go_to_section 5
        },
        MenuButton.new(420, :credits) {
          @form.go_to_section 6
        },
        MenuButton.new(470, :exit, true) {
          SB.save_options
          exit
        }
      ], [], [
        MenuButton.new(345, :continue) {
          SB.load_game @selected_game
        },
        MenuButton.new(395, :delete) {
          @form.go_to_section 4
        },
        MenuButton.new(445, :back, true) {
          @form.go_to_section 1
        }
      ], [
        (@txt_name = MenuTextField.new(295)),
        MenuText.new(:what_name, 400, 220, 400, :center),
        MenuButton.new(345, :play) {
          SB.new_game(@txt_name.text.downcase, @new_game_index) unless @txt_name.text.empty?
        },
        MenuButton.new(395, :back, true) {
          @form.go_to_section 1
        }
      ], [
        MenuText.new(:delete_confirm, 400, 270, 400, :center),
        MenuButton.new(345, :no, true) {
          @form.go_to_section 1
        },
        MenuButton.new(395, :yes) {
          File.delete(@selected_game)
          add_game_slots
          @form.go_to_section 1
        }
      ], Options.get_menu, [
        MenuButton.new(550, :back, true) {
          @form.go_to_section 0
        },
        MenuText.new(:credits_text, 400, 200, 780, :center)
      ], [
        MenuButton.new(550, :back, true) {
          @form.go_to_section 0
        },
        MenuText.new(:help_text, 400, 170, 700, :center)
      ])
      Options.form = @form

      add_game_slots
    end

    def update
      if @form.cur_section_index == 3 && @form.section(3).cur_btn == @txt_name && SB.key_pressed?(:confirm)
        SB.new_game(@txt_name.text.downcase, @new_game_index) unless @txt_name.text.empty?
      end
      @form.update
    end

    def reset
      @form.reset
      @txt_name.text = ''
      add_game_slots
      Options.form = @form
      SB.play_song Res.song(:main)
    end

    def update_lang
      @form.update_lang
    end

    def add_game_slots
      components = []
      @saved_games = []
      games = Dir["#{SB.save_dir}/*"].sort
      next_index = 0
      sound = Res.sound :btn1
      games.each do |g|
        file = g.split('/')[-1]
        next unless /^[0-9]$/ =~ file
        num = file.to_i
        (next_index...num).each do |i|
          components << NewGameButton.new(i + 1, 21 + (i % 2) * 390, 95 + (i / 2) * 90, self)
        end
        next_index = num + 1
        data = IO.readlines(g).map { |l| l.chomp }
        saved_game = SavedGame.new(num + 1, 21 + (num % 2) * 390, 95 + (num / 2) * 90, data[0], data[3], data[2], data[6], data[5])
        @saved_games << saved_game
        components << saved_game
        components <<
          SavedGameButton.new(21 + (num % 2) * 390, 95 + (num / 2) * 90) {
            @selected_game = g
            @form.go_to_section 2
            SB.play_sound sound
          }
      end
      (next_index...C::GAME_LIMIT).each do |i|
        components << NewGameButton.new(i + 1, 20 + (i % 2) * 390, 95 + (i / 2) * 90, self)
      end
      components << MenuButton.new(550, :back, true) {
        @form.go_to_section 0
      }
      components << MenuText.new(:choose_game, 780, 25, 380, :right)
      section = @form.section(1)
      section.clear
      components.each { |c| section.add(c) }
    end

    def go_to_new_game(index)
      @new_game_index = index
      @form.go_to_section 3
    end

    def draw
      @bg.draw 0, 0, 0, 2, 2
      @title.draw @form.cur_section_index == 1 ? 20 : 50, 20, 0, @form.cur_section_index == 1 ? 1 : 2, @form.cur_section_index == 1 ? 1 : 2
      @form.draw
    end
  end
end
