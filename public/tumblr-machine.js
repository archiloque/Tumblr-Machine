$(document).ready(function() {
    $(".tagsTable").tablesorter();
    $("#tagsTable1 tr").click(function(e) {
        var children = $(e.currentTarget).children();
        $('input[name=tagName]').val($(children[0]).children()[0].text);
        $('input[name=tagValue]').val($(children[1]).html());
        $('input[name=tagFetch]').attr('checked', $($(children[2]).children()[0]).text() == 'true');
    });
    $("#tagsTable2 tr").click(function(e) {
        var children = $(e.currentTarget).children();
        $('input[name=tagName]').val($(children[1]).children()[0].text);
        $('input[name=tagValue]').val(0);
        $('input[name=tagFetch]').attr('checked', false);
    });
});

function fetch(tag) {
    $.get('/fetch/' + tag, function(data) {
        displayMessage(data);
    });
}

function reblog(id) {
    if (confirm("Are you sure you want to reblog this post ?")) {
        $.get('/reblog/' + id, function(data) {
            displayMessage(data);
        });
    }
}

function displayMessage(message) {
    var displayResult = function() {
        $('#messages').append('<div id="notice" class="flash">' + message + '</div>');
    };
    if ($('.flash').length == 0) {
        displayResult();
    } else {
        $('.flash').fadeOut(function() {
            $('.flash').remove();
            displayResult();
        });
    }
}
