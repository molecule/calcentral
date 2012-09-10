var calcentral = calcentral || {};
calcentral.Widgets = calcentral.Widgets || {};
calcentral.Widgets.canvascourses = function(tuid) {

	/////////////////////////////
	// Configuration variables //
	/////////////////////////////

	var $rootel = $('#' + tuid);
	var $canvascoursesList = $('.cc-widget-canvascourses-list', $rootel);
	// Used to control whether or not to load the dummy feed.
	var dummy = false;
	// Hardcoded for the time being. Will be refactored out soon enough.
	var accountID = 90242;

	////////////////////
	// Event Handlers //
	////////////////////

	///////////////
	// Rendering //
	///////////////

	var renderCourses = function(data) {
		calcentral.Api.Util.renderTemplate({
			'container': $canvascoursesList,
			'data': {
				'courses': data
			},
			'template': $('#cc-widget-canvascourses-list-template', $rootel)
		});
	};

	///////////////////
	// Ajax Requests //
	///////////////////

	var getCanvasData = function(url) {
		return $.ajax({
			'url': url
		});
	}

	/**
	 * Will always load the list of dummy courses hardcoded for the widget.
	 * @return {Object} Ajax object for fetching the dummy couress.
	 */
	var loadDummyCourses = function() {
		return $.ajax({
			'cache': false,
			'url': '/widgets/canvascourses/dummy/canvascourses.json'
		});
	}

	/**
	 * Merge the the array of courses a user is enrolled in, with the list of all avaiable
	 * courses to extract information necessary for rendering the widget.
	 *
	 * @param  {Array} user_enrollment Array of JSONObjects of couress user is enrolled in.
	 * @param  {Array} allCourses Array of all the courses avaiable on canvas for this account.
	 * @return {Array} Array of JSONOjects, containing course name and course ID.
	 */
	var extractCourseNameAndId = function(user_enrollment, allCourses) {
		var courseIds = $.map(user_enrollment[0], function(value, index) {
			return value.course_id;
		});
		var renderData = $.map(allCourses[0], function(course, index) {
			if ($.inArray(course.id, courseIds) > -1) {
				return {
					'name' : course.course_code + ": " + course.name,
					'id': course.id
				};
			}
		});
		return renderData;
	}

	/**
	 * Fetch users's course data from canvas.
	 * @param  {Object} data Javascript Object containing uid and other urls to get data from.
	 * @return {Object} Deferred promise object for a Deferrred chain, with a (data) param.
	 */
	var loadCourses = function(data) {
		if (dummy) {
			return loadDummyCourses();
		} else {
			var $loadCoursesDeferred = $.Deferred();
			$.when(getCanvasData(data.enrollment_url), getCanvasData(data.courses_url)).done(function(user_enrollment, allCourses){
				var renderData = extractCourseNameAndId(user_enrollment, allCourses);
				$loadCoursesDeferred.resolve(renderData);
			}).fail(function() {
				loadDummyCourses().done(function(data) {
					$loadCoursesDeferred.resolve(data);
				});
			});
			return $loadCoursesDeferred.promise();
		}
	};

	////////////////////
	// Initialisation //
	////////////////////

	 // Initialise the canvas classes widget
	 var doInit = function(){
	 	/** Data available already for the current user, on every page. */
	 	var data = {
	 		'uid': calcentral.Data.User.user.uid,
	 		'enrollment_url': '/api/canvas/users/sis_user_id:' + calcentral.Data.User.user.uid + '/enrollments',
	 		'courses_url': '/api/canvas/accounts/' + accountID + '/courses'
	 	};

	 	$.when(loadCourses(data)).done(renderCourses);
	 };

	// Start the request
	doInit();
};