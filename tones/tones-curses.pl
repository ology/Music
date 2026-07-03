#!/usr/bin/env perl
#!/usr/bin/env perl
use strict;
use warnings;
use Curses::UI;

# Initialize the main UI instance configuration loop
my $cui = Curses::UI->new(
    -clear_on_exit => 1,
    -color_support => 1
);

# Generate a structural main layout window container
my $main_window = $cui->add(
    main_win => 'Window',
    -border => 1,
    -title  => 'Control'
);

# Append an informative text label widget
$main_window->add(
    info_label => 'Label',
    -text => 'Select an action:',
    -y    => 1,
    -x    => 2
);

my $actions = ['Create part', 'Modify part', 'Delete part', 'Quit'];
my %action_labels;
@action_labels{@$actions} = ('Create part', 'Modify part', 'Delete part', 'Quit');

# Append an interactive data listbox selection tool
my $listbox = $main_window->add(
    selection_list => 'Listbox',
    -x          => 2,
    -y          => 3,
    -border     => 1,
    -wraparound => 1,
    -values     => $actions,
    -labels     => { %action_labels },
    -onchange => \&handle_selection
);

# Intercept keyboard shortcut sequences to trigger application exit loops
$cui->set_binding(sub { exit 0 }, "\cQ"); # Ctrl+Q safely breaks execution
# Shift programmatic user interface input focus onto the selection menu listbox
$listbox->focus();
# Fire up the user interface application primary engine polling thread
$cui->mainloop();

# Trigger specific execution logic branches matching user selection
sub handle_selection {
    my $selected_value = $listbox->get_active_value();

    if ($selected_value eq 'Quit') {
        my $confirm_exit = $cui->dialog(
            -message => "Are you sure you want to exit?",
            -title   => "Close Window Confirmation",
            -buttons => ['yes', 'no']
        );
        exit 0 if $confirm_exit;
    } else {
        # Display an informational message modal matching selected execution item
        $cui->dialog(
            -message => "Run: $selected_value",
            -title   => "Task",
            -buttons => ['ok']
        );
    }
}
