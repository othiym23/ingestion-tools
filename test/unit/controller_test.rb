$: << File.expand_path(File.join(File.dirname(__FILE__), '..'))
$: << File.expand_path(File.join(File.dirname(__FILE__), '../../lib'))

require 'ingestion_case'
require 'ui/controller_state'
require 'flexmock'

class ControllerTest < IngestionCase
  def setup
    @model_mock = FlexMock.new
    ControllerState.model = @model_mock

    @context_mock = FlexMock.new
    ControllerState.context = @context_mock

    @control_mock = FlexMock.new
    ControllerState.control = @control_mock

    @status_mock = FlexMock.new
    ControllerState.status = @status_mock
    
    @logger_mock = FlexMock.new
    ControllerState.logger = @logger_mock

    @loader_mock = FlexMock.new
    ControllerState.archiver = @loader_mock

    @album_model = AlbumSelectionModel.new(@logger_mock, @loader_mock)
  end
  
  def test_generic_controller
    warn_text = ''
    @logger_mock.should_receive(:warn) { |message| warn_text = message }
    
    controller = ControllerState.default
    assert_nothing_raised { controller.enter }
    assert_equal "[ControllerState] abstract method 'enter' called", warn_text,
                 "Logging should signal that you called an abstract method"

    assert_nothing_raised { controller.exit }
    assert_equal "[ControllerState] abstract method 'exit' called", warn_text,
                 "Logging should signal that you called an abstract method"
  end

  def test_basic_start_state_startup
    warn_text = ''
    @model_mock.should_receive(:list) { nil }
    @logger_mock.should_receive(:warn) { |message| warn_text = message }
    
    controller = StartState.default
    assert_nothing_raised { controller.enter }
    assert_nothing_raised { controller.exit }
    assert_equal "[StartState] abstract method 'exit' called", warn_text,
                 "Logging should signal that you called an abstract method"
  end

  def test_start_state_screwball_entry
    list_called = false
    reset_called = false
    addmessage_args = []

    @model_mock.should_receive(:list, 1) { list_called = true; [] }
    @model_mock.should_receive(:reset_list!, 1) { reset_called = true }

    @status_mock.should_receive(:message=)

    @root_window_mock = FlexMock.new

    @context_mock.should_receive(:parent, 1) { @root_window_mock }
    @context_mock.should_receive(:addmessage, 1) {|component, message,key| addmessage_args = [component, message, key]}

    controller = StartState.default
    assert_nothing_raised { controller.enter }
    controller.dispatch('Z')
    assert_equal [@root_window_mock, :keypress, 'Z'], addmessage_args,
                 "pressing a random key just propagates that key up the component chain to be discarded."
  end

  def test_start_state_find_albums
    list_called = false
    @model_mock.should_receive(:list) { list_called = true; [] }
    reset_called = false
    @model_mock.should_receive(:reset_list!) { reset_called = true }
    @status_mock.should_receive(:message=)
    @control_mock.should_receive(:prompt_with_callback, 1)

    controller = StartState.default
    assert_nothing_raised { controller.enter }
    assert list_called, "list should be called by enter"
    assert reset_called, "reset_list! should be called by enter"
    controller.dispatch('f')
  end

  def test_start_state_recent_album
    list_called = false
    reset_called = false
    status_message = ''
    album = nil
    target_state = nil
    
    # Mock setup
    album_mock = FlexMock.new
    album_loader_mock = FlexMock.new
    
    # Test code
    controller = StartState.default
    
    @model_mock.should_receive(:list, 1) { list_called = true; [] }
    @model_mock.should_receive(:reset_list!, 1) { reset_called = true }
    @model_mock.should_receive(:selected=, 1) { |selected| album = selected }
    assert_nothing_raised { controller.enter }
    
    @status_mock.should_receive(:message=, 1) { |message| status_message = message}
    album_mock.should_receive(:artist_name, 1) { 'AR' }
    album_mock.should_receive(:reconstituted_name, 1) { 'AL' }
    album_loader_mock.should_receive(:choose_most_recent, 1) { album_mock }
    @context_mock.should_receive(:album_loader, 1) { album_loader_mock }
    @context_mock.should_receive(:change_state, 1) { |state| target_state = state }
    controller.dispatch('m')
    
    assert_equal album_mock, album
    assert_equal "AR - AL is the most recently added album", status_message
    assert_equal EditState, target_state
    
    # Mock verification
    @model_mock.mock_verify
    @status_mock.mock_verify
    album_mock.mock_verify
    album_loader_mock.mock_verify
    @context_mock.mock_verify
  end
end