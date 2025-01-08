;;;;
;;;; 2-D Mesh Library
;;;;

(defpackage :cafemielk/mesh2d
  (:use :cl :cafemielk/util)
  (:export
   :mesh2d-trig
   :mesh2d-trig-p
   :make-mesh2d-trig
   :mesh2d-unit-square
   :create-square-point-array
   :create-square-vise-array))
(in-package :cafemielk/mesh2d)


(defstruct mesh2d-trig
  (vertices nil :type (array * (* 2)))
  (vises nil :type (array fixnum (* 3))))

(defun create-square-point-array
    (x-coordinates y-coordinates &key (element-type t))
  (loop
    :with nx :of-type fixnum := (array-dimension x-coordinates 0)
    :with ny :of-type fixnum := (array-dimension y-coordinates 0)
    :with array := (make-array `(,(* nx ny) 2)
                               :element-type element-type)
    :for j :of-type fixnum :from 0
    :for yj :across y-coordinates
    :do
       (loop
         :with offset :of-type fixnum := (* nx j)
         :for i :of-type fixnum :from 0
         :for xi :across x-coordinates
         :do
            (setf (aref array (+ offset i) 0) xi)
            (setf (aref array (+ offset i) 1) yj))
    :finally
       (return array)))

(defun create-square-vise-array (nx ny)
  (loop
    :with array := (make-array `(,(* 2 (1- nx) (1- ny)) 3)
                               :element-type 'fixnum)
    :for j :from 0 :to (- ny 2)
    :do
       (loop
         :for i :from 0 :to (- nx 2)
         :do
            ;;           (j(nx+1)+i)   (j*(nx+1)+i+1)
            ;; j+1                 *---*
            ;;                     |  /|
            ;; [tij = 2j(nx-1)+2i] | / | [2j*(nx-1)+2i+1]
            ;;                     |/  |
            ;; j                   *---*
            ;;        (pij = j*nx+i)   (j*nx+i+1)
            ;;
            ;;                     i  i+1
            (let* ((pij (+ (* j nx) i))
                   (tij (* 2 (- pij j))))
              ;; upper left triangle
              (setf (aref array tij 0) (+ pij nx))
              (setf (aref array tij 1) pij)
              (setf (aref array tij 2) (+ pij nx 1))
              ;; lower right triangle
              (setf (aref array (1+ tij) 0) (+ pij 1))
              (setf (aref array (1+ tij) 1) (+ pij nx 1))
              (setf (aref array (1+ tij) 2) pij)))
    :finally
       (return array)))

(defun mesh2d-unit-square (nx ny)
  (make-mesh2d-trig
   :vertices (create-square-point-array
              (vector-linspace 0d0 1d0 nx :element-type 'double-float)
              (vector-linspace 0d0 1d0 ny :element-type 'double-float)
              :element-type 'double-float)
   :vises (create-square-vise-array nx ny)))

;;; Local Variables:
;;; mode: lisp
;;; indent-tabs-mode: nil
;;; End:
