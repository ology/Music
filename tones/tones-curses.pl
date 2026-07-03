#!/usr/bin/env perl
#!/usr/bin/env perl
use strict;
use warnings;
use Curses::UI;

# Initialize the main UI instance configuration loop
my $cui = Curses::UI->new(
    -clear_on_exit => 1,
    -color_support => 1,
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
    -x    => 2,
    -y    => 1,
);

my $actions = ['Create part', 'Modify part', 'Delete part', 'Play parts', 'Quit'];
my %action_labels;
@action_labels{@$actions} = (@$actions);

# Append an interactive data listbox selection tool
my $listbox = $main_window->add(
    selection_list => 'Listbox',
    -x          => 2,
    -y          => 3,
    -border     => 1,
    -wraparound => 1,
    -values     => $actions,
    -labels     => { %action_labels },
    -onchange   => \&handle_selection
);

# Intercept keyboard shortcut sequences to trigger application exit loops
$cui->set_binding(sub { exit 0 }, "\cQ"); # Ctrl+Q safely breaks execution
$cui->set_binding(\&handle_selection, "\cP");
# Shift programmatic user interface input focus onto the selection menu listbox
$listbox->focus();
# Fire up the user interface application primary engine polling thread
$cui->mainloop();

# Trigger specific execution logic branches matching user selection
sub handle_selection {
    my $selected_value = $listbox->get_active_value();
    if ($selected_value eq 'Quit') {
        my $confirm_exit = $cui->dialog(
            -message => "Exit?",
            -title   => "Quit",
            -buttons => ['yes', 'no']
        );
        exit 0 if $confirm_exit;
    }
    elsif ($selected_value eq 'Create part') {
        my $dialog = $cui->add(
            'profile_dialog', 'Window',
            -centered => 1,
            -width    => 50,
            -height   => 13,
            -border   => 1,
            -title    => 'Create Part',
        );

        # Add Label and Field for First Name
        $dialog->add(
            lbl1  => 'Label',
            -text => 'Name:',
            -x    => 2,
            -y    => 1,
        );
        my $txt_first = $dialog->add(
            first_name => 'TextEntry',
            -x         => 15,
            -y         => 1,
            -width     => 30,
            -border    => 1,
        );

        # Add Label and Field for Last Name
        $dialog->add(
            lbl2  => 'Label',
            -text => 'Motifs #:',
            -x    => 2,
            -y    => 4,
        );
        my $txt_last = $dialog->add(
            last_name => 'TextEntry',
            -x        => 15,
            -y        => 4,
            -width    => 30,
            -border   => 1,
        );

        # Variables to capture the submission state
        my $submitted = 0;

        $dialog->add(
            'buttons', 'Buttonbox',
            -x       => 13,
            -y       => 8,
            -buttons => [
                { 
                    -label   => '< OK >', 
                    -value   => 1, 
                    -onpress => sub { $submitted = 1; $dialog->loose_focus(); } 
                },
                { 
                    -label   => '< Cancel >', 
                    -value   => 0, 
                    -onpress => sub { $submitted = 0; $dialog->loose_focus(); } 
                }
            ],
        );

        # Enforce exclusive modal behavior and lock the code block here
        $txt_first->focus();
        $dialog->modalfocus(); 
        # --- Resumes Here After loose_focus() Is Triggered ---        
        # Pull values out of the text widgets before destroying the container
        my $first_name = $txt_first->get();
        my $last_name  = $txt_last->get();

        # Cleanup the dialog window object entirely from memory
        $cui->delete('profile_dialog');

        if ($submitted) {
            $cui->dialog("Profile Saved:\n\nName: $first_name $last_name");
        } else {
            $cui->dialog("Form Cancelled.");
        }
    }
    elsif ($selected_value eq 'Modify part') {
        $cui->dialog(
            -message => "Run: $selected_value",
            -title   => "Task",
            -buttons => ['ok']
        );
    }
    elsif ($selected_value eq 'Delete part') {
        $cui->dialog(
            -message => "Run: $selected_value",
            -title   => "Task",
            -buttons => ['ok']
        );
    }
    elsif ($selected_value eq 'Play parts') {
        $cui->dialog(
            -message => "Run: $selected_value",
            -title   => "Task",
            -buttons => ['ok']
        );
    }
}
