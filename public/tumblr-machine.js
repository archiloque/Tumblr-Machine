$(document).ready(function() {
    $("#tagsTable").tablesorter();
    $("#tagsTable tr").click(function(e) {
        var children = $(e.currentTarget).children();
        $('input[name=tagName]').val($(children[0]).children()[0].text);
        $('input[name=tagValue]').val($(children[1]).html());
        $('input[name=tagFetch]').attr('checked', $($(children[2]).children()[0]).text() == 'true');
    });
}
        );

function fetch(tag) {
    $.get('/fetch/' + tag, function(data) {
        var displayResult = function() {
            $('#messages').append('<div id="notice" class="flash">' + data + '</div>');
        };
        if ($('.flash').length == 0) {
            displayResult();
        } else {
            $('.flash').fadeOut(function() {
                $('.flash').remove();
                displayResult();
            });
        }
    });
}