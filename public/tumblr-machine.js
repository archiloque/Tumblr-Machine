$(document).ready(function() {
    $(".tagsTable").tablesorter();
     $('#tagsPosts').masonry({
    itemSelector : '.posts'
  });
});

function editTag(name, value, fetch) {
    $('input[name=tagName]').val(name);
    $('input[name=tagValue]').val(value);
    $('input[name=tagFetch]').attr('checked', fetch == 0);

}

function reblog(id) {
    if (confirm("Are you sure you want to reblog this post ?")) {
        callAndDisplayResult('/reblog/' + id);
    }
}

function seeAllTags() {
    $("#otherTags").remove();
    $.get('/otherTags', function(data) {
        $('body').append(data);
        $("#tagsTableOther tr").click(function(e) {
            var children = $(e.currentTarget).children();
            $('input[name=tagName]').val($(children[1]).children()[0].text);
            $('input[name=tagValue]').val(0);
            $('input[name=tagFetch]').attr('checked', false);
        });
    });
}

function callAndDisplayResult(url) {
    $.get(url, function(data) {
        displayMessage(data);
    });
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
