# (c) goodprogrammer.ru

require 'rails_helper'

# Тестовый сценарий для модели игрового вопроса,
# в идеале весь наш функционал (все методы) должны быть протестированы.
RSpec.describe GameQuestion, type: :model do

  # задаем локальную переменную game_question, доступную во всех тестах этого сценария
  # она будет создана на фабрике заново для каждого блока it, где она вызывается
  let(:game_question) { FactoryBot.create(:game_question, a: 2, b: 1, c: 4, d: 3) }

  # группа тестов на игровое состояние объекта вопроса
  context 'game status' do
    # тест на правильную генерацию хэша с вариантами
    it 'correct .variants' do
      expect(game_question.variants).to eq({'a' => game_question.question.answer2,
                                            'b' => game_question.question.answer1,
                                            'c' => game_question.question.answer4,
                                            'd' => game_question.question.answer3})
    end

    it 'correct .answer_correct?' do
      # именно под буквой b в тесте мы спрятали указатель на верный ответ
      expect(game_question.answer_correct?('b')).to be_truthy
    end
  end

  # help_hash у нас имеет такой формат:
  # {
  #   fifty_fifty: ['a', 'b'], # При использовании подсказски остались варианты a и b
  #   audience_help: {'a' => 42, 'c' => 37 ...}, # Распределение голосов по вариантам a, b, c, d
  #   friend_call: 'Василий Петрович считает, что правильный ответ A'
  # }
  #
  context 'game question' do
    it 'correct .level & .text delegates' do
      expect(game_question.text).to eq(game_question.question.text)
      expect(game_question.level).to eq(game_question.question.level)
    end
  end

  context 'user helpers' do
    it 'correct audience_help' do
      expect(game_question.help_hash).not_to include(:audience_help)

      game_question.add_audience_help

      expect(game_question.help_hash).to include(:audience_help)

      ah = game_question.help_hash[:audience_help]
      expect(ah.keys).to contain_exactly('a', 'b', 'c', 'd')
    end
  end

  describe '#add_fifty_fifty' do
    before(:each) do
      expect(game_question.help_hash).not_to include(:fifty_fifty)
    end

    context 'After its calling' do
      before(:each) do
        game_question.add_fifty_fifty
      end

      it 'adds a new help_hash element with correct values' do
        ff_value = game_question.help_hash[:fifty_fifty]
        expect(ff_value).to be
        expect(ff_value).to include(game_question.correct_answer_key)
        expect(ff_value.size).to eq 2
      end
    end
  end

  describe '#add_friend_call' do
    before(:each) do
      expect(game_question.help_hash).not_to include(:friend_call)
    end

    context 'After its calling' do
      before(:each) do
        game_question.add_friend_call
      end

      it 'adds a new help_hash element with correct value' do
        fc_value = game_question.help_hash[:friend_call]
        expect(fc_value).to be
        expect(fc_value).to be_kind_of String
      end
    end
  end

  describe '#correct_answer_key' do
    it 'returns correct answer key' do
      expect(game_question.correct_answer_key).to eq 'b'
    end
  end
end
